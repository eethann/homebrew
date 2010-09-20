require 'formula'

def mysql_installed?
    `which mysql_config`.length > 0
end

class Php <Formula
  url 'http://www.php.net/get/php-5.3.3.tar.gz/from/this/mirror'
  homepage 'http://php.net/'
  md5 '5adf1a537895c2ec933fddd48e78d8a2'
  version '5.3.3'

  # So PHP extensions don't report missing symbols
  skip_clean 'bin'

  depends_on 'jpeg'
  depends_on 'libpng'
  depends_on 'mcrypt'
  depends_on 'gettext'
  if ARGV.include? '--with-mysql'
    depends_on 'mysql' => :recommended unless mysql_installed?
  end
  
  def options
   [
     ['--with-mysql', 'Build with MySQL support.']
   ]
  end

  def patches
   DATA
  end
  
  def configure_args
    args = [
      "--prefix=#{prefix}",
      "--disable-debug",
      "--disable-dependency-tracking",
      "--with-config-file-path=#{prefix}/etc",
      "--with-iconv-dir=/usr",
      "--enable-exif",
      "--enable-soap",
      "--enable-sqlite-utf8",
      "--enable-wddx",
      "--enable-ftp",
      "--enable-sockets",
      "--enable-zip",
      "--enable-pcntl",
      "--enable-shmop",
      "--enable-sysvsem",
      "--enable-sysvshm",
      "--enable-sysvmsg",
      "--enable-memory-limit",
      "--enable-mbstring",
      "--enable-bcmath",
      "--enable-calendar",
      "--enable-memcache",
      "--with-openssl=/usr",
      "--with-zlib=/usr",
      "--with-bz2=/usr",
      "--with-ldap",
      "--with-ldap-sasl=/usr",
      "--with-xmlrpc",
      "--with-iodbc",
      "--with-kerberos=/usr",
      "--with-libxml-dir=/usr",
      "--with-xsl=/usr",
      "--with-curl=/usr",
      "--with-apxs2=/usr/sbin/apxs",
      "--libexecdir=#{prefix}/libexec",
      "--with-gd",
      "--enable-gd-native-ttf",
      "--with-mcrypt=#{Formula.factory('mcrypt').prefix}",
      "--with-jpeg-dir=#{Formula.factory('jpeg').prefix}",
      "--with-png-dir=#{Formula.factory('libpng').prefix}",
      "--with-gettext=#{Formula.factory('gettext').prefix}",
      "--with-tidy",
      "--mandir=#{man}"
    ]
    
    if ARGV.include? '--with-mysql'
      if mysql_installed?
        args.push "--with-mysql-sock=/tmp/mysql.sock"
        args.push "--with-mysqli=mysqlnd"
        args.push "--with-mysql=mysqlnd"
        args.push "--with-pdo-mysql=mysqlnd"
      else
        args.push "--with-mysqli=#{Formula.factory('mysql').bin}/mysql_config}"
        args.push "--with-mysql=#{Formula.factory('mysql').prefix}"
        args.push "--with-pdo-mysql=#{Formula.factory('mysql').prefix}"
      end
    end
    return args
  end
  
  def install
    ENV.O3 # Speed things up
    system "./configure", *configure_args

    # Use Homebrew prefix for the Apache libexec folder
    inreplace "Makefile",
      "INSTALL_IT = $(mkinstalldirs) '$(INSTALL_ROOT)/usr/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='$(INSTALL_ROOT)/usr/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so",
      "INSTALL_IT = $(mkinstalldirs) '#{prefix}/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='#{prefix}/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so"
    
    system "make"
    system "make install"

    system "cp ./php.ini-production #{prefix}/etc/php.ini"
  end

 def caveats; <<-EOS
   For 10.5 and Apache:
    Apache needs to run in 32-bit mode. You can either force Apache to start 
    in 32-bit mode or you can thin the Apache executable. The following page 
    has instructions for both methods:
    http://code.google.com/p/modwsgi/wiki/InstallationOnMacOSX
   
   To enable PHP in Apache add the following to httpd.conf and restart Apache:
    LoadModule php5_module    #{prefix}/libexec/apache2/libphp5.so

   Edits you will most likely want to make to php.ini
    Date:
      You will want to set date.timezone setting to your timezone.
      http://www.php.net/manual/en/timezones.php

    MySQL:
      pdo_mysql.default_socket = /tmp/mysql.sock
      mysql.default_port = 3306
      mysql.default_socket = /tmp/mysql.sock
      mysqli.default_socket = /tmp/mysql.sock

    The php.ini file can be found in:
      #{prefix}/etc/php.ini
   EOS
 end
end

__END__
diff -Naur php-5.3.2/ext/tidy/tidy.c php/ext/tidy/tidy.c 
--- php-5.3.2/ext/tidy/tidy.c	2010-02-12 04:36:40.000000000 +1100
+++ php/ext/tidy/tidy.c	2010-05-23 19:49:47.000000000 +1000
@@ -22,6 +22,8 @@
 #include "config.h"
 #endif
 
+#include "tidy.h"
+
 #include "php.h"
 #include "php_tidy.h"
 
@@ -31,7 +33,6 @@
 #include "ext/standard/info.h"
 #include "safe_mode.h"
 
-#include "tidy.h"
 #include "buffio.h"
 
 /* compatibility with older versions of libtidy */
