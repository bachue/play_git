require_relative 'binary'
require_relative 'cache'
require 'digest/sha1'
require 'time'

class Index
  def self.verify_header content
    hdr_signature, hdr_version, hdr_entries = content[0...12].unpack 'NNN'

    abort 'hdr_signature is invalid' unless hdr_signature == 0x44495243
    abort 'hdr_version   is invalid' unless (2..4).include?(hdr_version)

    [hdr_signature, hdr_version, hdr_entries]
  end

  def self.verify_index content
    ondisk, sha1sum = content[0...-20], content[-20..-1]
    abort 'Failed to validate the checksum' unless Digest::SHA1.digest(ondisk) == sha1sum
  end

  def self.each_index content, size, &block
    enumerator = Enumerator.new do |enum|
      iter_beg = 12
      loop do
        iter_end = iter_beg + 62
        break if iter_end >= size - 20
        ondisk = content[iter_beg...iter_end]

        index = new ondisk
        len   = index.flags & CE_NAMEMASK

        if index.flags & CE_EXTENDED != 0
          index.set_extended_flags content[iter_end...(iter_end + 2)]
          iter_end += 2
        end

        if len == CE_NAMEMASK
          name_beg, name_end = iter_end, iter_end
          name_end += 1 until content[name_end] == "\x00"
          index.name = content[name_beg...name_end]
          len = index.name.size
        else
          index.name = content[iter_end...(iter_end + len)]
        end

        enum << index
        iter_beg += (iter_end - iter_beg + len + 8) & ~7
      end
    end

    if block_given?
      enumerator.each &block
    else
      enumerator
    end
  end

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
