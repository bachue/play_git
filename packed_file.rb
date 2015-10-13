require 'zlib'

class PackedFile
  OBJ_BAD = -1
  OBJ_NONE = 0
  OBJ_COMMIT = 1
  OBJ_TREE = 2
  OBJ_BLOB = 3
  OBJ_TAG = 4
  OBJ_OFS_DELTA = 6
  OBJ_REF_DELTA = 7

  def initialize filename
    @filename = filename
    @size = File.size filename
  end

  def read_object offset
    File.open @filename, 'rb' do |file|
      file.seek offset
      c = file.read(1).unpack('C')[0]
      type = get_object_type((c >> 4) & 7)
      size = c & 15
      shift = 4
      while c & 80 != 0
        c = file.read(1).unpack('C')[0]
        size += (c & 0x7f) << shift
        shift += 7
      end
      zlib = Zlib::Inflate.new
      content = zlib.inflate file.read size
      zlib.finish
      zlib.close
      return type, size, content
    end
  end

private

  def get_object_type num
    {
      OBJ_BAD => 'OBJ_BAD',
      OBJ_NONE => 'OBJ_NONE',
      OBJ_COMMIT => 'OBJ_COMMIT',
      OBJ_TREE => 'OBJ_TREE',
      OBJ_BLOB => 'OBJ_BLOB',
      OBJ_TAG => 'OBJ_TAG',
      OBJ_OFS_DELTA => 'OBJ_OFS_DELTA',
      OBJ_REF_DELTA => 'OBJ_REF_DELTA'
    }[num]
  end
end
