require 'formula'

class Freetype <Formula
  @url='http://downloads.sourceforge.net/project/freetype/freetype2/2.3.11/freetype-2.3.11.tar.gz'
  @homepage='http://freetype.sourceforge.net'
  @md5='a693c9a4b0121890ca71e39364ffea4a'

# def deps
#   BinaryDep.new 'cmake'
# end

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking"
#   system "cmake . #{cmake_std_parameters}"
    system "make install"
  end
end
