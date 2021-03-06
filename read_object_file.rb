require_relative 'git_object'
require_relative 'git_commit'
require_relative 'git_tree'
require_relative 'git_tag'

def usage
  STDERR.puts <<-HELP
#$0 index_file
  HELP
end

unless ARGV[0]
  usage
  exit!
end

object = GitObject.read_from ARGV[0]

puts <<-OUTPUT
type: #{object.type}
size: #{object.size}
OUTPUT

case object.type
when 'tree'
  p GitTree.new(object)
when 'commit'
  p GitCommit.new(object)
when 'tag'
  p GitTag.new(object)
when 'blob'
  print object.data
else
  abort 'invalid object type'
end
