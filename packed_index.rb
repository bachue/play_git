class PackedIndex
  attr_accessor :hdr_signature, :hdr_version, :num_objects, :entries

  def initialize filename, idx_content
    @filename, @idx_content = filename.freeze, idx_content.freeze

    if @idx_content.size < 4 * 256 + 20 + 20
      abort "index file #{@filename} is too small"
    end

    @hdr_signature, @hdr_version = @idx_content[0...12].unpack 'NN'

    if @hdr_signature == 0xff744f63
      if @hdr_version < 2 || @hdr_version > 2
        abort "index file #{@filename} is version #{@hdr_version}" <<
              " and is not supported by this binary (try upgrading GIT to a newer version)"
      end
    else
      @hdr_version = 1
    end
  end

  def read_index
    iter_beg = @hdr_version == 1 ? 0 : 8
    @indices, @entries = @idx_content[iter_beg...(iter_beg + 256 * 4)].unpack('N' * 256), []
    iter_beg += 256 * 4
    nr = 0
    @indices.each do |n|
      abort "non-monotonic index #{@filename}" if n < nr
      nr = n
    end
    case @hdr_version
    when 1
      abort "wrong index v1 file size in #{@filename}" if @idx_content.size != 4 * 256 + nr * 24 + 20 + 20
      nr.times do
        sha1 = @idx_content[iter_beg...(iter_beg + 20)]
        offset = @idx_content[(iter_beg+20)...(iter_beg + 24)].unpack('N')[0]
        @entries << { sha1: sha1, offset: offset }
        iter_beg += 24
      end
    when 2
      min_size = 8 + 4 * 256 + nr * (20 + 4 + 4) + 20 + 20
      max_size = min_size
      max_size += (nr - 1) * 8 if nr
      abort "wrong index v2 file size in #{@filename}" if @idx_content.size < min_size || @idx_content.size > max_size
      nr.times do
        @entries << { sha1: @idx_content[iter_beg...(iter_beg + 20)] }
        iter_beg += 20
      end
      nr.times do |i|
        @entries[i].update crc: @idx_content[iter_beg...(iter_beg + 4)]
        iter_beg += 4
      end
      nr.times do |i|
        @entries[i].update offset: @idx_content[iter_beg...(iter_beg + 4)]
        iter_beg += 4
      end
    end
    @num_objects = nr
  end

  def search sha1
    idx = sha1[0].unpack('C')[0]
    hi, lo = @indices[idx], @indices[idx - 1]

    while lo < hi
      mi = (hi + lo) / 2
      case sha1 <=> @entries[mi][:sha1]
      when 0
        return mi
      when -1
        hi = mi
      when 1
        lo = mi + 1
      end
    end
    nil
  end
end
