require 'zlib'

class GitObject
  attr_accessor :data, :type, :size

  def self.read_from file
    File.open ARGV[0], 'rb' do |file|
      inflater = Zlib::Inflate.new
      data = inflater.inflate file.read 8192
      object = new

      type, size_str = '', ''
      consumed = data.index ' '
      type = data[0..consumed]
      consumed += 1
      object.type = type
      consumed += data[consumed..-1].index "\x00"
      consumed += 1
      object.size = size_str.to_i

      if data.size - consumed >= object.size
        object.data = data[consumed..-1]
      else
        object.data = data[consumed..-1] + inflater.inflate(file.read)
      end
      object
    end
  end
end
