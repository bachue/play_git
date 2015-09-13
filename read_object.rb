require_relative 'git_object'
require_relative 'git_commit'
require_relative 'git_tree'

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
else
  print object.data
end
