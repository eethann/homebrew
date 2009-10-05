require 'brewkit'

class Texlive <Formula
  url 'http://mirror.ctan.org/systems/texlive/tlnet/2008/install-tl-unx.tar.gz'
  version '2008'
  homepage 'http://www.tug.org/texlive/'
  md5 '985d8d8643f1aad838a423d940a39f0c'

  def install
    # Based on Richard Koch's excellent BasicTeX distribution:
    # http://www.uoregon.edu/~koch/BasicTeX.pdf
    profile = <<-EOF.gsub(/^\s+/, '')
      selected_scheme scheme-basic
      TEXDIR #{prefix}
      TEXDIRW #{prefix}
      TEXMFHOME $HOME/Library/texmf
      TEXMFLOCAL #{prefix}/texmf-local
      TEXMFSYSCONFIG #{prefix}/texmf-config
      TEXMFSYSVAR #{prefix}/texmf-var
      collection-basic 1
      collection-context 1
      collection-latex 1
      collection-latexrecommended 1
      collection-metapost 1
      collection-pstricks 1
      collection-xetex 1
      option_doc 0
      option_fmt 0
      option_letter 1
      option_src 0
      option_symlinks 0
    EOF

    IO.popen './install-tl --profile=/dev/stdin', 'w' do |io|
      io.write profile
    end
    # texlive installs binaries into a subdirectory of bin; make symlinks for
    # homebrew to find.
    bin = File.join(prefix, 'bin')
    subdir = 'universal-darwin'
    Dir[File.join(bin, subdir, '*')].each do |f|
      bn = File.basename f
      FileUtils.ln_s File.join(subdir, bn), File.join(bin, bn)
    end
  end
end
