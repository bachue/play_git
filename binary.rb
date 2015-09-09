class String
  def ntohl
    self.unpack('N*')[0]
  end

  def be16
    self.unpack('n')[0]
  end

  def be32
    self.unpack('N')[0]
  end
end
