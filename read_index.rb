require 'digest/sha1'

CE_NAMEMASK    = 0x0fff

CE_STAGEMASK   = 0x3000
CE_EXTENDED    = 0x4000
CE_VALID       = 0x8000
CE_STAGESHIFT  = 12

CE_UPDATE            = 1 << 16
CE_REMOVE            = 1 << 17
CE_UPTODATE          = 1 << 18
CE_ADDED             = 1 << 19
CE_HASHED            = 1 << 20
CE_WT_REMOVE         = 1 << 22
CE_CONFLICTED        = 1 << 23
CE_UNPACKED          = 1 << 24
CE_NEW_SKIP_WORKTREE = 1 << 25
CE_MATCHED           = 1 << 26
CE_UPDATE_IN_BASE    = 1 << 27
CE_STRIP_NAME        = 1 << 28
CE_INTENT_TO_ADD     = 1 << 29
CE_SKIP_WORKTREE     = 1 << 30
CE_EXTENDED2         = 1 << 31
CE_EXTENDED_FLAGS    = CE_INTENT_TO_ADD | CE_SKIP_WORKTREE

def usage
  STDERR.puts <<-HELP
#$0 index_file
  HELP
end

def bin_ntohl n
  n.unpack('N*')[0]
end

def bin_be16 bin
  bin.unpack('n')[0]
end

def bin_be32 bin
  bin.unpack('N')[0]
end

unless ARGV[0]
  usage
  exit!
end

file = File.open ARGV[0], 'rb'
size = file.stat.size.freeze
file_content = file.read.freeze
file.close

hdr_signature = bin_ntohl file_content[0...4]
hdr_version   = bin_ntohl file_content[4...8]
hdr_entries   = bin_ntohl file_content[8...12]

abort 'hdr_signature is invalid' unless hdr_signature == 0x44495243
abort 'hdr_version   is invalid' unless (2..4).include?(hdr_version)

puts "Signature: #{hdr_signature}"
puts "Version:   #{hdr_version}"
puts "Entries:   #{hdr_entries}"

ondisk, sha1sum = file_content[0...-20], file_content[-20..-1]

if Digest::SHA1.digest(ondisk) == sha1sum
  puts  'Succeed to validate the checksum'
else
  abort 'Failed to validate the checksum'
end
puts '-------------------------'

iter_beg = 12
loop do
  iter_end = iter_beg + 62
  break if iter_end >= size - 20
  ondisk = file_content[iter_beg...iter_end]
  ctime_sec  = bin_be32 ondisk[0...4]
  ctime_nsec = bin_be32 ondisk[4...8]
  mtime_sec  = bin_be32 ondisk[8...12]
  mtime_nsec = bin_be32 ondisk[12...16]
  dev        = bin_be32 ondisk[16...20]
  ino        = bin_be32 ondisk[20...24]
  mode       = bin_be32 ondisk[24...28]
  uid        = bin_be32 ondisk[28...32]
  gid        = bin_be32 ondisk[32...36]
  sz         = bin_be32 ondisk[36...40]
  sha1       = ondisk[40...60]
  flags      = bin_be16 ondisk[60...62]

  len        = flags & CE_NAMEMASK

  if flags & CE_EXTENDED != 0
    extended_flags = bin_be16(file_content[iter_end...(iter_end + 2)]) << 16
    iter_end += 2

    if extended_flags & ~CE_EXTENDED_FLAGS != 0
      abort 'Unknown index entry format %08x' % extended_flags
    end

    flags |= extended_flags
  end

  if len == CE_NAMEMASK
    name_beg, name_end = iter_end, iter_end
    name_end += 1 until file_content[name_end].unpack('c')[0] == 0
    name = file_content[name_beg...name_end]
    len = name.size
  else
    name = file_content[iter_end...(iter_end + len)]
  end

  puts <<-EOF
name:  #{name}
ctime: #{Time.at(ctime_sec, ctime_nsec.to_f / 1000)}
mtime: #{Time.at(mtime_sec, mtime_nsec.to_f / 1000)}
dev:   #{dev}
inode: #{ino}
mode:  #{mode.to_s(8)}
uid:   #{uid}
gid:   #{gid}
size:  #{sz}
sha1:  #{sha1.unpack('H*')[0]}
-------------------------
  EOF

  iter_beg += (iter_end - iter_beg + len + 8) & ~7
end
