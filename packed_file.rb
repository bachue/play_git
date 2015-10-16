require 'zlib'
require_relative 'git_repo'
require_relative 'git_object'

class PackedFile
  OBJ_BAD = -1
  OBJ_NONE = 0
  OBJ_COMMIT = 1
  OBJ_TREE = 2
  OBJ_BLOB = 3
  OBJ_TAG = 4
  OBJ_OFS_DELTA = 6
  OBJ_REF_DELTA = 7

  class Object < GitObject
    attr_accessor :base_offset, :base_sha1

    def initialize type, size, data
      @type, @size, @data = get_object_type(type), size, data
    end

  private

    def get_object_type num
      { OBJ_COMMIT => 'commit',
        OBJ_TREE => 'tree',
        OBJ_BLOB => 'blob',
        OBJ_TAG => 'tag',
        OBJ_OFS_DELTA => 'OFS_DELTA',
        OBJ_REF_DELTA => 'REF_DELTA'
      }[num]
    end
  end

  def initialize filename
    @filename = filename
    @size = File.size filename
  end

  def read_object offset, follow_delta: true
    File.open @filename, 'rb' do |file|
      object = read_object_from_file file, offset
      return object unless follow_delta
      delta_stack = []
      loop do
        delta_stack.push object
        case object.type
        when 'OFS_DELTA'
          object = read_object_from_file file, object.base_offset
        when 'REF_DELTA'
          git_repo = GitRepo.new File.expand_path('../../..', File.dirname(@filename))
          object = git_repo.read_object object.base_sha1
        else
          break
        end
      end
      base_obj = delta_stack.pop.dup
      until delta_stack.empty?
        patch_obj = delta_stack.pop
        result = patch_delta base_obj, patch_obj
        base_obj.data = result
        base_obj.size = result.bytesize
      end
      base_obj
    end
  end

private

  def read_object_from_file file, offset
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
    case type
    when OBJ_OFS_DELTA
      base_offset = read_ofs_delta file, offset
    when OBJ_REF_DELTA
      base_sha1 = read_ref_delta file
    end

    content = inflate_from_io file, size
    object = Object.new type, size, content
    if base_offset
      object.base_offset = base_offset
    elsif base_sha1
      object.base_sha1 = base_sha1
    end
    object
  end

  def read_ofs_delta file, delta_obj_offset
    c = file.read(1).unpack('C')[0]
    base_offset = c & 127
    while c & 128 != 0
      base_offset += 1
      c = file.read(1).unpack('C')[0]
      base_offset = (base_offset << 7) + (c & 127)
    end
    base_offset = delta_obj_offset - base_offset
    if base_offset <= 0 || base_offset >= delta_obj_offset
      abort 'out of bound'
    end
    base_offset
  end

  def read_ref_delta file
    file.read 20
  end

  def patch_delta base, patch
    result = ''
    data = patch.data
    size, iter = pop_patch_hdr_size data
    abort 'invalid patch' if size != base.data.bytesize
    data = data[iter..-1]
    size, iter = pop_patch_hdr_size data

    while iter < data.bytesize
      c = data[iter].unpack('C')[0]
      iter += 1
      if c & 0x80 != 0
        cp_off, cp_size = 0, 0
        bit, shift = 0, 0
        4.times do
          if c & (1 << bit) != 0
            cp_off |= (data[iter].unpack('C')[0] << shift)
            iter += 1
          end
          bit += 1
          shift += 8
        end
        shift = 0
        3.times do
          if c & (1 << bit) != 0
            cp_size |= (data[iter].unpack('C')[0] << shift)
            iter += 1
          end
          bit += 1
          shift += 8
        end
        cp_size = 0x10000 if cp_size.zero?
        abort 'invalid patch' if cp_off + cp_size > base.data.bytesize || cp_size > size
        result << base.data[cp_off...(cp_off + cp_size)]
        size -= cp_size
      elsif c != 0
        abort 'invalid patch' if c > size
        result << data[iter...(iter + c)]
        iter += c
        size -= c
      else
        abort 'unexpected delta opcode 0'
      end
    end

    abort 'invalid patch' unless size.zero?

    result
  end

  def pop_patch_hdr_size data
    size, iter, shift = 0, 0, 0
    loop do
      c = data[iter].unpack('C')[0]
      iter += 1
      size |= (c & 0x7f) << shift
      shift += 7
      break unless c & 0x80 != 0 && iter < data.bytesize
    end
    return size, iter
  end

  def inflate_from_io io, size, buf_size = 1024
    content = ''
    zlib = Zlib::Inflate.new
    zlib.avail_out = size
    until zlib.finished?
      content << zlib.inflate(io.read(buf_size))
    end
    zlib.close
    content
  end
end
