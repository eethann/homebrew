require 'brewkit'

class Libmcrypt <Formula
  @url='ftp://mirror.internode.on.net/pub/gentoo/distfiles/libmcrypt-2.5.8.tar.gz'
  @homepage='http://mcrypt.sourceforge.net'
  @md5='0821830d930a86a5c69110837c55b7da'

# def deps
#   BinaryDep.new 'cmake'
# end

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking"
#   system "cmake . #{cmake_std_parameters}"
    system "make install"
  end
end
