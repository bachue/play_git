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
size = file.stat.size.freeze
file_content = file.read.freeze
file.close

hdr_signature, hdr_version, hdr_entries = Index.verify_header file_content

puts "Signature: #{hdr_signature}"
puts "Version:   #{hdr_version}"
puts "Entries:   #{hdr_entries}"

Index.verify_index file_content
puts  'Succeed to validate the checksum'
puts '-------------------------'

Index.each_index file_content, size do |index|
  if index & CE_EXTENDED_FLAGS
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
sha1:  #{index.sha1_hex}
-------------------------
    EOF
  end
end
