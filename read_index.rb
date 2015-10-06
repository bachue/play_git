require_relative 'cache'
require_relative 'index'

def usage
  STDERR.puts <<-HELP
#$0 index_file
  HELP
end

unless ARGV[0]
  usage
  exit!
end

file = File.open ARGV[0], 'rb'
index = Index.new file.read.freeze
file.close

index.verify_header

puts "Signature: #{index.hdr_signature}"
puts "Version:   #{index.hdr_version}"
puts "Entries:   #{index.hdr_entries}"

index.verify_index
puts  'Succeed to validate the checksum'
puts '-------------------------'

index.each_index do |index|
  puts <<-EOF
name:  #{index.name}
ctime: #{index.ctime}
mtime: #{index.mtime}
dev:   #{index.dev}
inode: #{index.inode}
mode:  #{index.mode}
uid:   #{index.uid}
gid:   #{index.gid}
size:  #{index.size}
flags: #{index.read_flags}
sha1:  #{index.sha1_hex}
-------------------------
  EOF
end

if index.extension_existed?
  index.read_extension
  p index.extensions
end
