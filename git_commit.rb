require_relative 'tree_object'

class GitCommit
  attr_accessor :tree_sha1, :parents_sha1, :commit_message
                :author, :author_email, :author_time,
                :committer, :committer_email :committer_time

  def initialize object
    abort 'not git tree object' unless object.type == 'tree'
    abort 'bogus commit object' unless object.data.start_with? 'tree '
    offset = 'tree '.size
    @tree_sha1 = object.data[offset..(offset + 20)]
    offset += 20
    abort 'bogus commit object' unless object.data[offset] == "\n"

    @parents_sha1 = []
    while object.data[offset..-1].start_with? 'parent '
      offset += 'parent '.size
      @parents_sha1 << object.data[offset..(offset + 20)]
      offset += 20
      abort 'bad parents in commit object' unless object.data[offset] == "\n"
    end

    if object.data[offset..-1] =~ /\A(author\s+(\s+)<([^>]+)>\s+(\d+)\s+([+-]\d+))$/
      line = $1
      offset += line.size + 1
      name, email, timestamp, timezone = $2, $3, $4, $5
      @author, @author_email = name, email
      time = Time.at timestamp.to_i
      @author_time = DateTime.new(time.year, time.month, time.day, time.hour, time.min, time.sec, timezone).to_time
    end

    if object.data[offset..-1] =~ /\A(committer\s+(\s+)<([^>]+)>\s+(\d+)\s+([+-]\d+))$/
      line = $1
      offset += line.size + 1
      name, email, timestamp, timezone = $2, $3, $4, $5
      @committer, @committer_email = name, email
      time = Time.at timestamp.to_i
      @committer_time = DateTime.new(time.year, time.month, time.day, time.hour, time.min, time.sec, timezone).to_time
    end

    @commit_message = object.data[offset..-1]
  end
end
