require_relative 'git_object'

class GitRepo
  def initialize path
    @path = File.absolute_path path
    abort 'Not a Git Repo Path' if File.directory?("#{@path}/.git")
  end

  def read_object sha1
    sha1_hex = sha1.unpack 'H40'
    guess_path = "#{@path}/.git/objects/#{sha1_hex[0..1]}/#{sha1_hex[2..-1]}"
    if File.exists?(guess_path)
      abort "Invalid object file #{guess_path}" unless File.file?(guess_path)
      abort 'Permission Denied' unless File.readable?(guess_path)
      object = GitObject.read_from guess_path
      return object.data, object.type
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
          object = PackedFile.new(pack_file).read_object offset
          return object.data, object.type
        end
      end
      return nil
    end
  end
end
