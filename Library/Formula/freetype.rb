require 'brewkit'

class Freetype <Formula
  @url='http://mirror.dknss.com/nongnu/freetype/freetype-2.3.9.tar.gz'
  @homepage='http://freetype.sourceforge.net'
  @md5='9c2744f1aa72fe755adda33663aa3fad'

# def deps
#   BinaryDep.new 'cmake'
# end

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking"
#   system "cmake . #{cmake_std_parameters}"
    system "make install"
  end
end
