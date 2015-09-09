require 'zlib'

class GitObject
  attr_accessor :data, :type, :size

  def self.read_from file
    File.open ARGV[0], 'rb' do |file|
      inflater = Zlib::Inflate.new
      data = inflater.inflate file.read 8192
      object = new

      type, size_str = nil, nil
      consumed = data.each_byte.each_with_index { |c, i| c == 0x20 ? break i : type << c.chr }
      consumed += 1
      object.type = type
      data[consumed..-1].each_byte.each_with_index { |c, i| c == 0 ? break i : size_str << c.chr }
      consumed += 1
      object.size = size_str.to_i

      if data.size - consumed >= size
        object.data = data[consumed..-1]
      else
        object.data = data[consumed..-1] + inflater.inflate(file.read)
      end
      object
    end
  end
end
