require_relative 'git_repo'
require_relative 'git_object'
require_relative 'git_commit'
require_relative 'git_tree'
require_relative 'git_tag'

def usage
  STDERR.puts <<-HELP
#$0 sha1 [git-repo-path]
  HELP
end

unless ARGV[0]
  usage
  exit!
end

sha1 = [ARGV[0]].pack 'H40'
if sha1.bytesize != 20
  usage
  exit!
end

repo = ARGV[1] && !ARGV[1].empty? ? GitRepo.new(ARGV[1]) : GitRepo.from_cwd
object = repo.read_object sha1
abort 'not found' unless object

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
