require_relative 'binary'
require_relative 'cache'
require 'digest/sha1'
require 'time'
require 'set'

class Index
  attr_reader :hdr_signature, :hdr_version, :hdr_entries, :extensions
  def initialize content
    @content = content
    @hdr_signature, @hdr_version, @hdr_entries = content[0...12].unpack 'NNN'
  end

  def verify_header
    abort 'hdr_signature is invalid' unless @hdr_signature == 0x44495243
    abort 'hdr_version   is invalid' unless (2..4).include?(@hdr_version)
  end

  def verify_index
    ondisk, sha1sum = @content[0...-20], @content[-20..-1]
    abort 'Failed to validate the checksum' unless Digest::SHA1.digest(ondisk) == sha1sum
  end

  def each_index &block
    iter_beg = 12

    enumerator = Enumerator.new do |enum|
      @hdr_entries.times do
        iter_end = iter_beg + 62
        ondisk = @content[iter_beg...iter_end]

        index = Entry.new ondisk
        len   = index.flags & CE_NAMEMASK

        if index.flags & CE_EXTENDED != 0
          index.set_extended_flags @content[iter_end...(iter_end + 2)]
          iter_end += 2
        end

        if len == CE_NAMEMASK
          name_beg, name_end = iter_end, iter_end
          name_end += 1 until @content[name_end] == "\x00"
          index.name = @content[name_beg...name_end]
          len = index.name.size
        else
          index.name = @content[iter_end...(iter_end + len)]
        end

        enum << index
        iter_beg += (iter_end - iter_beg + len + 8) & ~7
      end

      @ext_content = @content[iter_beg...-20] if iter_beg <= @content.size - 8 - 20
    end


    if block_given?
      enumerator.each &block
    else
      enumerator
    end
  end

  def extension_existed?
    !!@ext_content
  end

  def read_extension
    iter_beg = 0
    @extensions = []
    while iter_beg <= @ext_content.size - 8
      ext_sig, ext_size = @ext_content[iter_beg...(iter_beg + 4)], @ext_content[(iter_beg + 4)...(iter_beg + 8)]
      ext_size = ext_size.unpack('N')[0]
      ext = { sig: ext_sig, size: ext_size }
      content = @ext_content[(iter_beg + 8)..(iter_beg + 8 + ext_size)]
      case ext_sig
      when 'TREE'
        ext.update cache_tree: read_cache_tree(content)
      when 'REUC'
        ext.update resolve_undo: read_resolve_undo(content)
      when 'link'
        puts 'link'
      else
        if ('A'..'Z').include?(ext_sig[0])
          STDERR.puts "Ignoring #{ext_sig} extension"
        else
          abort "Index uses #{ext_sig} extension, which we do not understand"
        end
      end
      @extensions << ext
      iter_beg += 8 + ext_size
    end
  end

private

  def read_cache_tree content
    cache_tree, _ = read_sub_cache_tree '', content
    cache_tree
  end

  def read_sub_cache_tree name, content
    iter_end = content.index "\x00"
    iter_beg = iter_end + 1
    iter_end = content.index ' '
    entry_point = content[iter_beg...iter_end].to_i
    iter_beg = iter_end + 1
    iter_end = content.index "\n"
    subtree_nr = content[iter_beg...iter_end].to_i
    iter_beg = iter_end + 1
    sha1 = content[iter_beg...(iter_beg + 20)]
    cache_tree = CacheTree.new name, entry_point, subtree_nr, sha1
    content = content[(iter_beg + 20)..-1]

    subtree_nr.times do
      iter_end = content.index "\x00"
      name = content[0...iter_end]
      child, content = read_sub_cache_tree name, content
      cache_tree.add_children child
    end

    return cache_tree, content
  end

  def read_resolve_undo content
    resolve_undo = []

    until content.empty?
      iter_beg = 0
      iter_end = content.index "\x00"
      name = content[iter_beg...iter_end]
      content = content[(iter_end + 1)..-1]

      ui = [{}, {}, {}]

      3.times do |i|
        iter_end = content.index "\x00"
        ui[i].update mode: content[0...iter_end]
        content = content[(iter_end + 1)..-1]
      end
      iter_beg = 0

      3.times do |i|
        ui[i].update sha1: content[iter_beg...(iter_beg + 20)]
        iter_beg += 20
      end

      content = content[iter_beg..-1]
      resolve_undo << ResolveUndo.new(name, ui)
    end

    resolve_undo
  end

  class Entry
    attr_accessor :ctime, :mtime, :dev, :inode, :mode, :uid, :gid, :size, :sha1, :flags, :name
    def initialize content
      ctime_sec, ctime_nsec, mtime_sec, mtime_nsec,
      @dev, @inode, mode, @uid, @gid, @size = content[0...40].unpack 'N*'

      @ctime     = Time.at ctime_sec, ctime_nsec.to_f / 1000
      @mtime     = Time.at mtime_sec, mtime_nsec.to_f / 1000
      @mode      = mode.to_s 8
      @sha1      = content[40...60]
      @flags     = content[60...62].unpack('n')[0]
    end

    def sha1_hex
      @sha1.unpack('H*')[0]
    end

    def read_flags
      CEFlags.explain @flags
    end

    def set_extended_flags content
      extended_flags = content.be16 << 16
      if extended_flags & ~CE_EXTENDED_FLAGS != 0
        abort 'Unknown index entry format %08x' % extended_flags
      end
      @flags |= extended_flags
    end
  end

  class CacheTree
    attr_accessor :entry_point, :subtree_nr, :sha1, :name

    def initialize name, entry_point, subtree_nr, sha1
      @name, @entry_point, @subtree_nr, @sha1 = name, entry_point, subtree_nr, sha1
    end

    def sha1_hex
      @sha1.unpack('H*')[0]
    end

    def add_children child
      @children ||= Set.new
      @children << child
    end
  end

  class ResolveUndo
    attr_accessor :name, :ours, :theirs, :base

    class Entry
      attr_accessor :mode, :sha1

      def initialize mode, sha1
        @mode, @sha1 = mode, sha1
      end

      def sha1_hex
        @sha1.unpack('H*')[0]
      end
    end

    def initialize name, util
      @name   = name
      @base   = Entry.new util[0][:mode], util[0][:sha1]
      @ours   = Entry.new util[1][:mode], util[1][:sha1]
      @theirs = Entry.new util[2][:mode], util[2][:sha1]
    end
  end
end
