class GitTree
  class Entry
    attr_accessor :mode_str, :filename, :sha1

    def mode
      mode_str.to_i 8
    end
  end

  attr_accessor :entries

  def initialize object
    abort 'not a git tree object' unless object.type == 'tree'
    data, entries = object.data, []

    until data.empty?
      entry = Entry.new
      space = data.index ' '
      mode_str = data[0...space]
      entry.mode_str = mode_str

      data = data[(space + 1)..-1]
      space = data.index "\x00"
      filename = data[0...space]
      entry.filename = filename

      sha1 = data[(space + 1)...(space + 20 + 1)]
      entry.sha1 = sha1

      entries << entry
      data = data[(space + 20 + 1)..-1]
    end
  end
end
