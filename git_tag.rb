class GitTag
  attr_accessor :sha1, :type, :name, :tagger_name, :tagger_email, :tagger_time, :annotation

  def initialize object
    abort 'not a git tag object' unless object.type == 'tag'
    abort 'invalid git tag' if object.size < 64
    abort 'invalid git tag' unless object.data[0...7] == 'object ' &&
                                   object.data[47] == "\n" &&
                                   object.data[48...53] == 'type '
    @sha1 = object.data[7...47]

    data = object.data[53..-1]
    nl = data.index "\n"
    abort 'invalid git tag' unless nl

    @type = data[0...nl]
    abort 'invalid git tag' unless data[(nl + 1)...(nl + 5)] == 'tag '

    data = data[(nl + 5)..-1]
    nl = data.index "\n"
    abort 'invalid git tag' unless nl

    @name = data[0...nl]
    if data[(nl + 1)...(nl + 8)] == 'tagger '
      data = data[(nl + 8)..-1]
      tagger, @annotation = data.split "\n", 2
      nl = data.index "\n"
      tagger = data[0...nl]
      @annotation = data[(nl + 1)..-1]

      if tagger =~ /^([^<]+)\s+<([^>]+)>\s+(\d+)\s+([+-]\d+)$/
        @tagger_name, @tagger_email, timestamp, timezone = $1, $2, $3, $4
        time = Time.at timestamp.to_i
        @tagger_time = DateTime.new(time.year, time.month, time.day, time.hour, time.min, time.sec, timezone).to_time
      else
        abort 'invalid tagger'
      end
    else
      @annotation = data[(nl + 1)..-1]
    end
  end

  def sha1_hex
    @sha1.unpack('H*')[0]
  end
end
