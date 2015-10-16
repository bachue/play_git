require_relative 'git_object'
require_relative 'packed_index'
require_relative 'packed_file'

class GitRepo
  def self.from_cwd
    current = '.'
    cwd_dev = File.stat(current).dev
    dev = cwd_dev
    while cwd_dev == dev && current != '/'
      return new current if File.directory?("#{current}/.git")
      current = File.expand_path('..', current)
    end
    abort 'Not in a Git Repo Path'
  end

  def initialize path
    @path = File.absolute_path path
    abort 'Not a Git Repo Path' unless File.directory?("#{@path}/.git")
  end

  def read_object sha1
    sha1_hex = sha1.unpack('H40')[0]
    guess_path = "#{@path}/.git/objects/#{sha1_hex[0..1]}/#{sha1_hex[2..-1]}"
    if File.exists?(guess_path)
      abort "Invalid object file #{guess_path}" unless File.file?(guess_path)
      abort 'Permission Denied' unless File.readable?(guess_path)
      GitObject.read_from guess_path
    else
      Dir["#{@path}/.git/objects/pack/pack-*.idx"].each do |idx_file|
        abort "Invalid pack index file #{idx_file}" unless File.file?(idx_file)
        abort "Permission Denied" unless File.readable?(idx_file)
        File.open(idx_file, 'rb') do |file|
          content = file.read
          packed_index = PackedIndex.new idx_file, content
          packed_index.read_index
          offset = packed_index.search sha1
          next unless offset
          pack_file = idx_file.gsub(/\.idx$/, '.pack')
          abort "Invalid pack file #{pack_file}" unless File.file?(pack_file)
          abort "Permission Denied" unless File.readable?(pack_file)
          return PackedFile.new(pack_file).read_object offset
        end
      end
      return nil
    end
  end
end
