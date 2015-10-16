require 'zlib'

class GitObject
  attr_accessor :data, :type, :size

  def self.read_from file
    File.open file, 'rb' do |f|
      inflater = Zlib::Inflate.new
      data = inflater.inflate f.read 8192
      object = new

      consumed = data.index ' '
      type = data[0...consumed]
      consumed += 1
      object.type = type
      size_beg = consumed
      consumed += data[consumed..-1].index "\x00"
      object.size = data[size_beg...consumed].to_i
      consumed += 1

      if data.size - consumed >= object.size
        object.data = data[consumed..-1]
      else
        object.data = data[consumed..-1] + inflater.inflate(f.read)
      end
      inflater.close
      object
    end
  end
end
