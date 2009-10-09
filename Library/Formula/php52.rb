require 'brewkit'

class Php52 <Formula
  @url='http://www.php.net/get/php-5.2.11.tar.bz2/from/www.php.net/mirror'
  @version='5.2.11'
  @homepage='http://php.net/'
  @md5='286bf34630f5643c25ebcedfec5e0a09'

  depends_on 'jpeg'
  depends_on 'freetype'
  depends_on 'libpng'
  depends_on 'libmcrypt'
  depends_on 'libiconv'
  if ARGV.include? '--with-mysql'
      depends_on 'mysql' => :recommended
  end

  def options
    [
      ['--with-apache', "Install the Apache module"],
      ['--with-mysql',  "Build with MySQL (PDO) support"],
      ['--with-pear', "Install PEAR PHP package manager after build"]
    ]
  end
  
  def caveats
    <<-END_CAVEATS
Pass --with-apache to build with the Apache SAPI
Pass --with-mysql  to build with MySQL (PDO) support
Pass --with-pear   to install PEAR PHP package manager after build
    END_CAVEATS
  end

  def skip_clean? path
    path == bin+'php'
  end

  def install
    configure_args = [
      "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking",
        "--with-ldap=/usr",
        "--with-kerberos=/usr",
        "--enable-cli",
        "--with-zlib-dir=/usr",
        "--enable-exif",
        "--enable-ftp",
        "--enable-mbstring",
        "--enable-mbregex",
        "--enable-sockets",
        "--with-iodbc=/usr",
        "--with-curl=/usr",
        "--with-config-file-path=#{prefix}/etc",
        "--sysconfdir=/private/etc",
        "--with-openssl=/usr",
        "--with-xmlrpc",
        "--with-xsl=/usr",
        "--without-pear",
        "--with-libxml-dir=/usr",
        "--with-iconv=#{HOMEBREW_PREFIX}",
        "--with-gd",
        "--with-jpeg-dir=#{HOMEBREW_PREFIX}",
        "--with-png-dir=#{HOMEBREW_PREFIX}",
        "--with-freetype-dir=#{HOMEBREW_PREFIX}",
        "--with-mcrypt=#{HOMEBREW_PREFIX}"]
    
    if ARGV.include? '--with-apache'
      puts "Building with the Apache SAPI; may require sudo password."
      # system "sudo cp /usr/libexec/apache2/libphp5.so /usr/libexec/apache2/libphp5.3.apple.so"
      configure_args.push("--with-apxs2=/usr/sbin/apxs")
      configure_args.push("--libexecdir=#{prefix}/libexec")
    else
      puts "Not building the Apache SAPI. Pass --with-apache if needed."
    end
    
    if ARGV.include? '--with-mysql'
        configure_args.push("--with-mysql-sock=/tmp/mysql",
        "--with-mysqli=#{HOMEBREW_PREFIX}/bin/mysql_config",
        "--with-mysql=#{HOMEBREW_PREFIX}/lib/mysql",
        "--with-pdo-mysql=#{HOMEBREW_PREFIX}/bin/mysql_config")
    else
        puts "Not building MySQL (PDO) support. Pass --with-mysql if needed."
    end
    
    system "./configure", *configure_args
    
    mkfile = File.open("Makefile")
    newmk  = File.new("Makefile.fix", "w")
    mkfile.each do |line|
        if /^EXTRA_LIBS =(.*)$/ =~ line
            newmk.print "EXTRA_LIBS =", $1, " -lresolv\n"
        elsif /^MH_BUNDLE_FLAGS =(.*)$/ =~ line
            newmk.print "MH_BUNDLE_FLAGS =", $1, " -lresolv\n"
        elsif /\$\(CC\) \$\(MH_BUNDLE_FLAGS\)/ =~ line
            newmk.print "\t", '$(CC) $(CFLAGS_CLEAN) $(EXTRA_CFLAGS) $(LDFLAGS) $(EXTRA_LDFLAGS) $(PHP_GLOBAL_OBJS:.lo=.o) $(PHP_SAPI_OBJS:.lo=.o) $(PHP_FRAMEWORKS) $(EXTRA_LIBS) $(ZEND_EXTRA_LIBS) $(MH_BUNDLE_FLAGS) -o $@ && cp $@ libs/libphp$(PHP_MAJOR_VERSION).so', "\n"
        elsif /^INSTALL_IT =(.*)$/ =~ line
            newmk.print "INSTALL_IT = $(mkinstalldirs) '#{prefix}/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='#{prefix}/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so", "\n"
        else
            newmk.print line
        end
    end
    newmk.close
    system "cp Makefile.fix Makefile"
    
    if ARGV.include? '--with-apache'
      system "make install"
      system "mkdir #{prefix}/etc"
      system "cp ./php.ini-recommended #{prefix}/etc/php.ini"
      puts "Apache module installed at #{prefix}/libexec/apache2/libphp.so"
      puts "You can symlink to it in /usr/libexec/apache2, edit httpd.conf and restart your webserver"
    else
      system "make"
      system "make install"
    end
    
    if ARGV.include? '--with-pear'
      system "curl http://pear.php.net/go-pear | #{prefix}/bin/php"
    end
  end
end
