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
      type = (c >> 4) & 7
      size = c & 15
      shift = 4
      while c & 0x80 != 0
        c = file.read(1).unpack('C')[0]
        size += (c & 0x7f) << shift
        shift += 7
      end
      read_delta type, file, offset
      zlib = Zlib::Inflate.new
      content = zlib.inflate file.read size
      zlib.close
      return type, size, content, @base_offset, @base_sha1
    end
  end

private

  def read_delta type, file, offset
    case type
    when OBJ_OFS_DELTA
      read_ofs_delta file, offset
    when OBJ_REF_DELTA
      read_ref_delta file
    end
  end

  def read_ofs_delta file, delta_obj_offset
    c = file.read(1).unpack('C')[0]
    base_offset = c & 127
    while c & 128 != 0
      base_offset += 1
      c = file.read(1).unpack('C')[0]
      base_offset = (base_offset << 7) + (c & 127)
    end
    @base_offset = delta_obj_offset - base_offset
    if @base_offset <= 0 || @base_offset >= delta_obj_offset
      abort 'out of bound'
    end
  end

  def read_ref_delta file
    @base_sha1 = file.read 20
  end

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
