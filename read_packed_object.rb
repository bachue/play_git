require_relative 'packed_index'
require_relative 'packed_file'

sha1, file = ARGV

abort 'Invalid sha1' if sha1.nil? || sha1.size != 40
sha1 = [sha1].pack 'H40'

ext = File.extname(file)
abort 'Invalid pack file' unless ext == '.pack' || ext == '.idx'

pack_file  = ext == '.pack' ? file : file.gsub(/#{Regexp.escape(ext)}$/, '.pack')
index_file = ext == '.idx'  ? file : file.gsub(/#{Regexp.escape(ext)}$/, '.idx')

index = File.open(index_file, 'rb').read

packed_index = PackedIndex.new index_file, index
packed_index.read_index

offset = packed_index.search sha1

packed_file = PackedFile.new pack_file
p packed_file.read_object offset
