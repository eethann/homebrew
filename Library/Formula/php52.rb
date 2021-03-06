require 'formula'

class Php52 <Formula
  @url='http://www.php.net/get/php-5.2.17.tar.bz2/from/www.php.net/mirror'
  @version='5.2.17'
  @homepage='http://php.net/'
  @md5='b27947f3045220faf16e4d9158cbfe13'

  depends_on 'jpeg'
  depends_on 'freetype'
  depends_on 'libpng'
  depends_on 'libmcrypt'
  depends_on 'libiconv'
  if ARGV.include? '--with-mysql'
      depends_on 'mysql'
  end
  if ARGV.include? '--with-mariadb'
      depends_on 'mariadb'
  end
  if ARGV.include? '--fpm'
    exit if ARGV.include? '--with-apache'
    depends_on 'libevent'
  end
  
  def options
    [
      ['--with-apache', "Install the Apache module"],
      ['--with-mysql',  "Build with MySQL (PDO) support"],
      ['--with-mariadb',  "Build with MySQL (PDO) support via MariaDB"],
      ['--fpm', "Build with 'FastCGI Process Manager' patch"]
    ]
  end
  
  def patches
    # PHP-FPM patch (http://php-fpm.org)
    return DATA if ARGV.include? '--fpm'
  end

  def caveats
    <<-END_CAVEATS
Pass --with-apache to build with the Apache SAPI
Pass --with-mysql  to build with MySQL (PDO) support
Pass --with-mariadb  to build with MySQL (PDO) support via MariaDB
Pass --fpm to build with FastCGI Process Manager support
    END_CAVEATS
  end

  # def skip_clean? path
  #   path == bin+'php'
  # end
  skip_clean ['bin', 'sbin']

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
        "--with-iconv=#{Formula.factory('libiconv').prefix}",
        "--with-gd",
        "--with-jpeg-dir=#{HOMEBREW_PREFIX}",
        "--with-png-dir=#{Formula.factory('libpng').prefix}",
        "--with-freetype-dir=#{HOMEBREW_PREFIX}",
        "--with-mcrypt=#{HOMEBREW_PREFIX}",
        "--mandir=#{man}"]
    
    if ARGV.include? '--with-apache'
      puts "Building with the Apache SAPI"
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
    elsif ARGV.include? '--with-mariadb'
        configure_args.push("--with-mysql-sock=/tmp/mysql",
        "--with-mysqli=#{HOMEBREW_PREFIX}/bin/mysql_config",
        "--with-mysql=#{HOMEBREW_PREFIX}/lib/mysql",
        "--with-pdo-mysql=#{HOMEBREW_PREFIX}/bin/mysql_config")
    else
        puts "Not building MySQL (PDO) support. Pass --with-mysql if needed."
    end
    
    if ARGV.include? '--fpm'
      system "./buildconf --force"
      configure_args.push(
        "--enable-fastcgi",
        "--enable-fpm",
        "--with-libevent=#{Formula.factory('libevent').prefix}"
      )
    end

    system "./configure", *configure_args
    
    if ARGV.include? '--with-apache'
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
            if ARGV.include? '--with-apache'
              newmk.print "INSTALL_IT = $(mkinstalldirs) '#{prefix}/libexec/apache2' && $(mkinstalldirs) '$(INSTALL_ROOT)/private/etc/apache2' && /usr/sbin/apxs -S LIBEXECDIR='#{prefix}/libexec/apache2' -S SYSCONFDIR='$(INSTALL_ROOT)/private/etc/apache2' -i -a -n php5 libs/libphp5.so", "\n"
            else
              newmk.print line
            end
          else
              newmk.print line
          end
      end
      newmk.close
      system "cp Makefile.fix Makefile"
    end
    
    if ARGV.include? '--with-apache'
      system "make install"
      puts "Apache module installed at #{prefix}/libexec/apache2/libphp.so"
      puts "You can symlink to it in /usr/libexec/apache2, edit httpd.conf and restart your webserver"
    else
      system "make"
      system "make install"
    end

    system "mkdir #{prefix}/etc" unless ARGV.include? "--fpm"
    system "cp ./php.ini-recommended #{prefix}/etc/php.ini"
  end
end
__END__
diff --git a/configure b/configure
index 2d88ed7..c490abf 100755
--- a/configure
+++ b/configure
@@ -773,6 +773,17 @@ ac_help="$ac_help
   --disable-path-info-check CGI: If this is disabled, paths such as
                             /info.php/test?a=b will fail to work"
 ac_help="$ac_help
+  --enable-fpm              FastCGI: If this is enabled, the fastcgi support
+                            will include experimental process manager code"
+ac_help="$ac_help
+  --with-fpm-conf=PATH        Set the path for php-fpm configuration file [PREFIX/etc/php-fpm.conf]"
+ac_help="$ac_help
+  --with-fpm-log=PATH         Set the path for php-fpm log file [PREFIX/logs/php-fpm.log]"
+ac_help="$ac_help
+  --with-fpm-pid=PATH         Set the path for php-fpm pid file [PREFIX/logs/php-fpm.pid]"
+ac_help="$ac_help
+  --with-xml-config=PATH      FPM: use xml-config in PATH to find libxml"
+ac_help="$ac_help
 
 General settings:
 "
@@ -12153,11 +12164,30 @@ ext_output=$PHP_PATH_INFO_CHECK
 
 
 
+php_enable_fpm=no
+
+
+# Check whether --enable-fpm or --disable-fpm was given.
+if test "${enable_fpm+set}" = set; then
+  enableval="$enable_fpm"
+  PHP_FPM=$enableval
+else
+
+  PHP_FPM=no
+
+  if test "$PHP_ENABLE_ALL" && test "no" = "yes"; then
+    PHP_FPM=$PHP_ENABLE_ALL
+  fi
+
+fi
+
+
+ext_output=$PHP_FPM
 
 
 if test "$PHP_SAPI" = "default"; then
   echo $ac_n "checking whether to build CGI binary""... $ac_c" 1>&6
-echo "configure:12161: checking whether to build CGI binary" >&5
+echo "configure:12435: checking whether to build CGI binary" >&5
   if test "$PHP_CGI" != "no"; then
     echo "$ac_t""yes" 1>&6
     
@@ -12194,8 +12224,25 @@ EOF
 
     echo "$ac_t""$PHP_FASTCGI" 1>&6
 
+        if test "$PHP_FASTCGI" = "yes"; then
+      echo $ac_n "checking whether to enable FastCGI Process Manager""... $ac_c" 1>&6
+echo "configure:12474: checking whether to enable FastCGI Process Manager" >&5
+      if test "$PHP_FPM" = "yes"; then
+        PHP_FASTCGI_PM=1
+      else
+        PHP_FASTCGI_PM=0
+      fi
+      echo "$ac_t""$PHP_FPM" 1>&6
+    else
+      PHP_FASTCGI_PM=0
+    fi
+    cat >> confdefs.h <<EOF
+#define PHP_FASTCGI_PM $PHP_FASTCGI_PM
+EOF
+
+
         echo $ac_n "checking whether to force Apache CGI redirect""... $ac_c" 1>&6
-echo "configure:12199: checking whether to force Apache CGI redirect" >&5
+echo "configure:12490: checking whether to force Apache CGI redirect" >&5
     if test "$PHP_FORCE_CGI_REDIRECT" = "yes"; then
       CGI_REDIRECT=1
     else
@@ -12410,10 +12457,10 @@ EOF
         BUILD_CGI="echo '\#! .' > php.sym && echo >>php.sym && nm -BCpg \`echo \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) | sed 's/\([A-Za-z0-9_]*\)\.lo/\1.o/g'\` | \$(AWK) '{ if (((\$\$2 == \"T\") || (\$\$2 == \"D\") || (\$\$2 == \"B\")) && (substr(\$\$3,1,1) != \".\")) { print \$\$3 } }' | sort -u >> php.sym && \$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) -Wl,-brtl -Wl,-bE:php.sym \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
         ;;
       *darwin*)
-        BUILD_CGI="\$(CC) \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(NATIVE_RPATHS) \$(PHP_GLOBAL_OBJS:.lo=.o) \$(PHP_SAPI_OBJS:.lo=.o) \$(PHP_FRAMEWORKS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
+        BUILD_CGI="\$(CC) \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(NATIVE_RPATHS) \$(PHP_GLOBAL_OBJS:.lo=.o) \$(PHP_SAPI_OBJS:.lo=.o) \$(PHP_FRAMEWORKS) \$(EXTRA_LIBS) \$(SAPI_EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
       ;;
       *)
-        BUILD_CGI="\$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
+        BUILD_CGI="\$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(SAPI_EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
       ;;
     esac
 
@@ -12476,6 +12523,875 @@ fi
 
 fi
 
+if test "$PHP_FASTCGI" = "yes" -a "$PHP_FPM" = "yes"; then
+  
+  echo "$ac_t""" 1>&6
+  echo "$ac_t""${T_MD}Running FastCGI Process Manager checks${T_ME}" 1>&6
+
+  
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+  
+FPM_VERSION="0.5.14"
+
+
+php_with_fpm_conf=\$prefix/etc/php-fpm.conf
+
+echo $ac_n "checking for php-fpm config file path""... $ac_c" 1>&6
+echo "configure:12798: checking for php-fpm config file path" >&5
+# Check whether --with-fpm-conf or --without-fpm-conf was given.
+if test "${with_fpm_conf+set}" = set; then
+  withval="$with_fpm_conf"
+  PHP_FPM_CONF=$withval
+else
+  
+  PHP_FPM_CONF=\$prefix/etc/php-fpm.conf
+
+  if test "$PHP_ENABLE_ALL" && test "no" = "yes"; then
+    PHP_FPM_CONF=$PHP_ENABLE_ALL
+  fi
+
+fi
+
+
+ext_output=$PHP_FPM_CONF
+echo "$ac_t""$ext_output" 1>&6
+
+
+
+
+
+php_with_fpm_log=\$prefix/logs/php-fpm.log
+
+echo $ac_n "checking for php-fpm log file path""... $ac_c" 1>&6
+echo "configure:12824: checking for php-fpm log file path" >&5
+# Check whether --with-fpm-log or --without-fpm-log was given.
+if test "${with_fpm_log+set}" = set; then
+  withval="$with_fpm_log"
+  PHP_FPM_LOG=$withval
+else
+  
+  PHP_FPM_LOG=\$prefix/logs/php-fpm.log
+
+  if test "$PHP_ENABLE_ALL" && test "no" = "yes"; then
+    PHP_FPM_LOG=$PHP_ENABLE_ALL
+  fi
+
+fi
+
+
+ext_output=$PHP_FPM_LOG
+echo "$ac_t""$ext_output" 1>&6
+
+
+
+
+
+php_with_fpm_pid=\$prefix/logs/php-fpm.pid
+
+echo $ac_n "checking for php-fpm pid file path""... $ac_c" 1>&6
+echo "configure:12850: checking for php-fpm pid file path" >&5
+# Check whether --with-fpm-pid or --without-fpm-pid was given.
+if test "${with_fpm_pid+set}" = set; then
+  withval="$with_fpm_pid"
+  PHP_FPM_PID=$withval
+else
+  
+  PHP_FPM_PID=\$prefix/logs/php-fpm.pid
+
+  if test "$PHP_ENABLE_ALL" && test "no" = "yes"; then
+    PHP_FPM_PID=$PHP_ENABLE_ALL
+  fi
+
+fi
+
+
+ext_output=$PHP_FPM_PID
+echo "$ac_t""$ext_output" 1>&6
+
+
+
+
+FPM_SOURCES="fpm.c \
+	fpm_conf.c \
+	fpm_signals.c \
+	fpm_children.c \
+	fpm_worker_pool.c \
+	fpm_unix.c \
+	fpm_cleanup.c \
+	fpm_sockets.c \
+	fpm_stdio.c \
+	fpm_env.c \
+	fpm_events.c \
+	fpm_php.c \
+	fpm_php_trace.c \
+	fpm_process_ctl.c \
+	fpm_request.c \
+	fpm_clock.c \
+	fpm_shm.c \
+	fpm_shm_slots.c \
+	xml_config.c \
+	zlog.c"
+
+
+	echo "$ac_t""checking for XML configuration" 1>&6
+
+	# Check whether --with-xml-config or --without-xml-config was given.
+if test "${with_xml_config+set}" = set; then
+  withval="$with_xml_config"
+  XMLCONFIG="$withval"
+else
+  for ac_prog in xml2-config xml-config
+do
+# Extract the first word of "$ac_prog", so it can be a program name with args.
+set dummy $ac_prog; ac_word=$2
+echo $ac_n "checking for $ac_word""... $ac_c" 1>&6
+echo "configure:12906: checking for $ac_word" >&5
+if eval "test \"`echo '$''{'ac_cv_path_XMLCONFIG'+set}'`\" = set"; then
+  echo $ac_n "(cached) $ac_c" 1>&6
+else
+  case "$XMLCONFIG" in
+  /*)
+  ac_cv_path_XMLCONFIG="$XMLCONFIG" # Let the user override the test with a path.
+  ;;
+  ?:/*)			 
+  ac_cv_path_XMLCONFIG="$XMLCONFIG" # Let the user override the test with a dos path.
+  ;;
+  *)
+  IFS="${IFS= 	}"; ac_save_ifs="$IFS"; IFS=":"
+  ac_dummy="$PATH"
+  for ac_dir in $ac_dummy; do 
+    test -z "$ac_dir" && ac_dir=.
+    if test -f $ac_dir/$ac_word; then
+      ac_cv_path_XMLCONFIG="$ac_dir/$ac_word"
+      break
+    fi
+  done
+  IFS="$ac_save_ifs"
+  ;;
+esac
+fi
+XMLCONFIG="$ac_cv_path_XMLCONFIG"
+if test -n "$XMLCONFIG"; then
+  echo "$ac_t""$XMLCONFIG" 1>&6
+else
+  echo "$ac_t""no" 1>&6
+fi
+
+test -n "$XMLCONFIG" && break
+done
+test -n "$XMLCONFIG" || XMLCONFIG=""""
+
+	
+fi
+
+
+	if test "x$XMLCONFIG" = "x"; then
+		{ echo "configure: error: XML configuration could not be found" 1>&2; exit 1; }
+	else
+        echo $ac_n "checking for libxml library""... $ac_c" 1>&6
+echo "configure:12950: checking for libxml library" >&5
+
+		if test ! -x "$XMLCONFIG"; then
+			{ echo "configure: error: $XMLCONFIG cannot be executed" 1>&2; exit 1; }
+		fi
+
+		LIBXML_LIBS="`$XMLCONFIG --libs`"
+		LIBXML_CFLAGS="`$XMLCONFIG --cflags`"
+		LIBXML_VERSION="`$XMLCONFIG --version`"
+
+        echo "$ac_t""yes, $LIBXML_VERSION" 1>&6
+
+		
+	SAVED_CFLAGS="$CFLAGS"
+	CFLAGS="$CFLAGS $LIBXML_CFLAGS"
+	SAVED_LIBS="$LIBS"
+	LIBS="$LIBS $LIBXML_LIBS"
+
+	echo $ac_n "checking for xmlParseFile""... $ac_c" 1>&6
+echo "configure:12969: checking for xmlParseFile" >&5
+if eval "test \"`echo '$''{'ac_cv_func_xmlParseFile'+set}'`\" = set"; then
+  echo $ac_n "(cached) $ac_c" 1>&6
+else
+  cat > conftest.$ac_ext <<EOF
+#line 12974 "configure"
+#include "confdefs.h"
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char xmlParseFile(); below.  */
+#include <assert.h>
+/* Override any gcc2 internal prototype to avoid an error.  */
+/* We use char because int might match the return type of a gcc2
+    builtin and then its argument prototype would still apply.  */
+char xmlParseFile();
+
+int main() {
+
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_xmlParseFile) || defined (__stub___xmlParseFile)
+choke me
+#else
+xmlParseFile();
+#endif
+
+; return 0; }
+EOF
+if { (eval echo configure:12997: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext}; then
+  rm -rf conftest*
+  eval "ac_cv_func_xmlParseFile=yes"
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  eval "ac_cv_func_xmlParseFile=no"
+fi
+rm -f conftest*
+fi
+
+if eval "test \"`echo '$ac_cv_func_'xmlParseFile`\" = yes"; then
+  echo "$ac_t""yes" 1>&6
+  :
+else
+  echo "$ac_t""no" 1>&6
+{ echo "configure: error: Failed to link with libxml" 1>&2; exit 1; }
+fi
+
+
+	CFLAGS="$SAVED_CFLAGS"
+	LIBS="$SAVED_LIBS"
+
+
+		cat >> confdefs.h <<\EOF
+#define HAVE_LIBXML 1
+EOF
+
+	fi
+
+
+	echo $ac_n "checking for prctl""... $ac_c" 1>&6
+echo "configure:13030: checking for prctl" >&5
+
+	cat > conftest.$ac_ext <<EOF
+#line 13033 "configure"
+#include "confdefs.h"
+ #include <sys/prctl.h> 
+int main() {
+prctl(0, 0, 0, 0, 0);
+; return 0; }
+EOF
+if { (eval echo configure:13040: \"$ac_compile\") 1>&5; (eval $ac_compile) 2>&5; }; then
+  rm -rf conftest*
+  
+		cat >> confdefs.h <<\EOF
+#define HAVE_PRCTL 1
+EOF
+
+		echo "$ac_t""yes" 1>&6
+	
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  
+		echo "$ac_t""no" 1>&6
+	
+fi
+rm -f conftest*
+
+
+	have_clock_gettime=no
+
+	echo $ac_n "checking for clock_gettime""... $ac_c" 1>&6
+echo "configure:13063: checking for clock_gettime" >&5
+
+	cat > conftest.$ac_ext <<EOF
+#line 13066 "configure"
+#include "confdefs.h"
+ #include <time.h> 
+int main() {
+struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
+; return 0; }
+EOF
+if { (eval echo configure:13073: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext}; then
+  rm -rf conftest*
+  
+		have_clock_gettime=yes
+		echo "$ac_t""yes" 1>&6
+	
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  
+		echo "$ac_t""no" 1>&6
+	
+fi
+rm -f conftest*
+
+	if test "$have_clock_gettime" = "no"; then
+		echo $ac_n "checking for clock_gettime in -lrt""... $ac_c" 1>&6
+echo "configure:13091: checking for clock_gettime in -lrt" >&5
+
+		SAVED_LIBS="$LIBS"
+		LIBS="$LIBS -lrt"
+
+		cat > conftest.$ac_ext <<EOF
+#line 13097 "configure"
+#include "confdefs.h"
+ #include <time.h> 
+int main() {
+struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
+; return 0; }
+EOF
+if { (eval echo configure:13104: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext}; then
+  rm -rf conftest*
+  
+			have_clock_gettime=yes
+			echo "$ac_t""yes" 1>&6
+		
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  
+			LIBS="$SAVED_LIBS"
+			echo "$ac_t""no" 1>&6
+		
+fi
+rm -f conftest*
+	fi
+
+	if test "$have_clock_gettime" = "yes"; then
+		cat >> confdefs.h <<\EOF
+#define HAVE_CLOCK_GETTIME 1
+EOF
+
+	fi
+
+	have_clock_get_time=no
+
+	if test "$have_clock_gettime" = "no"; then
+		echo $ac_n "checking for clock_get_time""... $ac_c" 1>&6
+echo "configure:13133: checking for clock_get_time" >&5
+
+		if test "$cross_compiling" = yes; then
+    { echo "configure: error: can not run test program while cross compiling" 1>&2; exit 1; }
+else
+  cat > conftest.$ac_ext <<EOF
+#line 13139 "configure"
+#include "confdefs.h"
+ #include <mach/mach.h>
+			#include <mach/clock.h>
+			#include <mach/mach_error.h>
+
+			int main()
+			{
+				kern_return_t ret; clock_serv_t aClock; mach_timespec_t aTime;
+				ret = host_get_clock_service(mach_host_self(), REALTIME_CLOCK, &aClock);
+
+				if (ret != KERN_SUCCESS) {
+					return 1;
+				}
+
+				ret = clock_get_time(aClock, &aTime);
+				if (ret != KERN_SUCCESS) {
+					return 2;
+				}
+
+				return 0;
+			}
+		
+EOF
+if { (eval echo configure:13163: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext} && (./conftest; exit) 2>/dev/null
+then
+  
+			have_clock_get_time=yes
+			echo "$ac_t""yes" 1>&6
+		
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -fr conftest*
+  
+			echo "$ac_t""no" 1>&6
+		
+fi
+rm -fr conftest*
+fi
+
+	fi
+
+	if test "$have_clock_get_time" = "yes"; then
+		cat >> confdefs.h <<\EOF
+#define HAVE_CLOCK_GET_TIME 1
+EOF
+
+	fi
+
+
+	have_ptrace=no
+	have_broken_ptrace=no
+
+	echo $ac_n "checking for ptrace""... $ac_c" 1>&6
+echo "configure:13194: checking for ptrace" >&5
+
+	cat > conftest.$ac_ext <<EOF
+#line 13197 "configure"
+#include "confdefs.h"
+
+		#include <sys/types.h>
+		#include <sys/ptrace.h> 
+int main() {
+ptrace(0, 0, (void *) 0, 0);
+; return 0; }
+EOF
+if { (eval echo configure:13206: \"$ac_compile\") 1>&5; (eval $ac_compile) 2>&5; }; then
+  rm -rf conftest*
+  
+		have_ptrace=yes
+		echo "$ac_t""yes" 1>&6
+	
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  
+		echo "$ac_t""no" 1>&6
+	
+fi
+rm -f conftest*
+
+	if test "$have_ptrace" = "yes"; then
+		echo $ac_n "checking whether ptrace works""... $ac_c" 1>&6
+echo "configure:13224: checking whether ptrace works" >&5
+
+		if test "$cross_compiling" = yes; then
+    { echo "configure: error: can not run test program while cross compiling" 1>&2; exit 1; }
+else
+  cat > conftest.$ac_ext <<EOF
+#line 13230 "configure"
+#include "confdefs.h"
+
+			#include <unistd.h>
+			#include <signal.h>
+			#include <sys/wait.h>
+			#include <sys/types.h>
+			#include <sys/ptrace.h>
+			#include <errno.h>
+
+			#if !defined(PTRACE_ATTACH) && defined(PT_ATTACH)
+			#define PTRACE_ATTACH PT_ATTACH
+			#endif
+
+			#if !defined(PTRACE_DETACH) && defined(PT_DETACH)
+			#define PTRACE_DETACH PT_DETACH
+			#endif
+
+			#if !defined(PTRACE_PEEKDATA) && defined(PT_READ_D)
+			#define PTRACE_PEEKDATA PT_READ_D
+			#endif
+
+			int main()
+			{
+				long v1 = (unsigned int) -1; /* copy will fail if sizeof(long) == 8 and we've got "int ptrace()" */
+				long v2;
+				pid_t child;
+				int status;
+
+				if ( (child = fork()) ) { /* parent */
+					int ret = 0;
+
+					if (0 > ptrace(PTRACE_ATTACH, child, 0, 0)) {
+						return 1;
+					}
+
+					waitpid(child, &status, 0);
+
+			#ifdef PT_IO
+					struct ptrace_io_desc ptio = {
+						.piod_op = PIOD_READ_D,
+						.piod_offs = &v1,
+						.piod_addr = &v2,
+						.piod_len = sizeof(v1)
+					};
+
+					if (0 > ptrace(PT_IO, child, (void *) &ptio, 0)) {
+						ret = 1;
+					}
+			#else
+					errno = 0;
+
+					v2 = ptrace(PTRACE_PEEKDATA, child, (void *) &v1, 0);
+
+					if (errno) {
+						ret = 1;
+					}
+			#endif
+					ptrace(PTRACE_DETACH, child, (void *) 1, 0);
+
+					kill(child, SIGKILL);
+
+					return ret ? ret : (v1 != v2);
+				}
+				else { /* child */
+					sleep(10);
+					return 0;
+				}
+			}
+		
+EOF
+if { (eval echo configure:13301: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext} && (./conftest; exit) 2>/dev/null
+then
+  
+			echo "$ac_t""yes" 1>&6
+		
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -fr conftest*
+  
+			have_ptrace=no
+			have_broken_ptrace=yes
+			echo "$ac_t""no" 1>&6
+		
+fi
+rm -fr conftest*
+fi
+
+	fi
+
+	if test "$have_ptrace" = "yes"; then
+		cat >> confdefs.h <<\EOF
+#define HAVE_PTRACE 1
+EOF
+
+	fi
+
+	have_mach_vm_read=no
+
+	if test "$have_broken_ptrace" = "yes"; then
+		echo $ac_n "checking for mach_vm_read""... $ac_c" 1>&6
+echo "configure:13332: checking for mach_vm_read" >&5
+
+		cat > conftest.$ac_ext <<EOF
+#line 13335 "configure"
+#include "confdefs.h"
+ #include <mach/mach.h>
+			#include <mach/mach_vm.h>
+		
+int main() {
+
+			mach_vm_read((vm_map_t)0, (mach_vm_address_t)0, (mach_vm_size_t)0, (vm_offset_t *)0, (mach_msg_type_number_t*)0);
+		
+; return 0; }
+EOF
+if { (eval echo configure:13346: \"$ac_compile\") 1>&5; (eval $ac_compile) 2>&5; }; then
+  rm -rf conftest*
+  
+			have_mach_vm_read=yes
+			echo "$ac_t""yes" 1>&6
+		
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -rf conftest*
+  
+			echo "$ac_t""no" 1>&6
+		
+fi
+rm -f conftest*
+	fi
+
+	if test "$have_mach_vm_read" = "yes"; then
+		cat >> confdefs.h <<\EOF
+#define HAVE_MACH_VM_READ 1
+EOF
+
+	fi
+
+	proc_mem_file=""
+
+	if test -r /proc/$$/mem ; then
+		proc_mem_file="mem"
+	else
+		if test -r /proc/$$/as ; then
+			proc_mem_file="as"
+		fi
+	fi
+
+	if test -n "$proc_mem_file" ; then
+		echo $ac_n "checking for proc mem file""... $ac_c" 1>&6
+echo "configure:13382: checking for proc mem file" >&5
+
+		if test "$cross_compiling" = yes; then
+    { echo "configure: error: can not run test program while cross compiling" 1>&2; exit 1; }
+else
+  cat > conftest.$ac_ext <<EOF
+#line 13388 "configure"
+#include "confdefs.h"
+
+			#define _GNU_SOURCE
+			#define _FILE_OFFSET_BITS 64
+			#include <stdint.h>
+			#include <unistd.h>
+			#include <sys/types.h>
+			#include <sys/stat.h>
+			#include <fcntl.h>
+			#include <stdio.h>
+			int main()
+			{
+				long v1 = (unsigned int) -1, v2 = 0;
+				char buf[128];
+				int fd;
+				sprintf(buf, "/proc/%d/$proc_mem_file", getpid());
+				fd = open(buf, O_RDONLY);
+				if (0 > fd) {
+					return 1;
+				}
+				if (sizeof(long) != pread(fd, &v2, sizeof(long), (uintptr_t) &v1)) {
+					close(fd);
+					return 1;
+				}
+				close(fd);
+				return v1 != v2;
+			}
+		
+EOF
+if { (eval echo configure:13418: \"$ac_link\") 1>&5; (eval $ac_link) 2>&5; } && test -s conftest${ac_exeext} && (./conftest; exit) 2>/dev/null
+then
+  
+			echo "$ac_t""$proc_mem_file" 1>&6
+		
+else
+  echo "configure: failed program was:" >&5
+  cat conftest.$ac_ext >&5
+  rm -fr conftest*
+  
+			proc_mem_file=""
+			echo "$ac_t""no" 1>&6
+		
+fi
+rm -fr conftest*
+fi
+
+	fi
+
+	if test -n "$proc_mem_file"; then
+		cat >> confdefs.h <<EOF
+#define PROC_MEM_FILE "$proc_mem_file"
+EOF
+
+	fi
+
+	if test "$have_ptrace" = "yes"; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_ptrace.c"
+	elif test -n "$proc_mem_file"; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_pread.c"
+	elif test "$have_mach_vm_read" = "yes" ; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_mach.c"
+	fi
+
+
+
+LIBEVENT_CFLAGS="-I$abs_srcdir/libevent"
+LIBEVENT_LIBS="$abs_builddir/libevent/libevent.a"
+
+SAPI_EXTRA_DEPS="$LIBEVENT_LIBS"
+
+FPM_CFLAGS="$LIBEVENT_CFLAGS $LIBXML_CFLAGS $JUDY_CFLAGS"
+
+FPM_CFLAGS="$FPM_CFLAGS -I$abs_srcdir/sapi/cgi" # for fastcgi.h
+
+if test "$ICC" = "yes" ; then
+	FPM_ADD_CFLAGS="-Wall -wd279,310,869,810,981"
+elif test "$GCC" = "yes" ; then
+	FPM_ADD_CFLAGS="-Wall -Wpointer-arith -Wno-unused-parameter -Wunused-variable -Wunused-value -fno-strict-aliasing"
+fi
+
+if test -n "$FPM_WERROR" ; then
+	FPM_ADD_CFLAGS="$FPM_ADD_CFLAGS -Werror"
+fi
+
+FPM_CFLAGS="$FPM_ADD_CFLAGS $FPM_CFLAGS"
+
+
+  src=$abs_srcdir/sapi/cgi/fpm/Makefile.frag
+  ac_srcdir=$ext_srcdir
+  ac_builddir=$ext_builddir
+  test -f "$src" && $SED -e "s#\$(srcdir)#$ac_srcdir#g" -e "s#\$(builddir)#$ac_builddir#g" $src  >> Makefile.fragments
+
+
+
+  
+  case sapi/cgi/fpm in
+  "") ac_srcdir="$abs_srcdir/"; unset ac_bdir; ac_inc="-I. -I$abs_srcdir" ;;
+  /*) ac_srcdir=`echo "sapi/cgi/fpm"|cut -c 2-`"/"; ac_bdir=$ac_srcdir; ac_inc="-I$ac_bdir -I$abs_srcdir/$ac_bdir" ;;
+  *) ac_srcdir="$abs_srcdir/sapi/cgi/fpm/"; ac_bdir="sapi/cgi/fpm/"; ac_inc="-I$ac_bdir -I$ac_srcdir" ;;
+  esac
+  
+  
+
+  b_c_pre=$php_c_pre
+  b_cxx_pre=$php_cxx_pre
+  b_c_meta=$php_c_meta
+  b_cxx_meta=$php_cxx_meta
+  b_c_post=$php_c_post
+  b_cxx_post=$php_cxx_post
+  b_lo=$php_lo
+
+
+  old_IFS=$IFS
+  for ac_src in $FPM_SOURCES; do
+  
+      IFS=.
+      set $ac_src
+      ac_obj=$1
+      IFS=$old_IFS
+      
+      PHP_SAPI_OBJS="$PHP_SAPI_OBJS $ac_bdir$ac_obj.lo"
+
+      case $ac_src in
+        *.c) ac_comp="$b_c_pre $FPM_CFLAGS $ac_inc $b_c_meta -c $ac_srcdir$ac_src -o $ac_bdir$ac_obj.$b_lo $b_c_post" ;;
+        *.s) ac_comp="$b_c_pre $FPM_CFLAGS $ac_inc $b_c_meta -c $ac_srcdir$ac_src -o $ac_bdir$ac_obj.$b_lo $b_c_post" ;;
+        *.S) ac_comp="$b_c_pre $FPM_CFLAGS $ac_inc $b_c_meta -c $ac_srcdir$ac_src -o $ac_bdir$ac_obj.$b_lo $b_c_post" ;;
+        *.cpp|*.cc|*.cxx) ac_comp="$b_cxx_pre $FPM_CFLAGS $ac_inc $b_cxx_meta -c $ac_srcdir$ac_src -o $ac_bdir$ac_obj.$b_lo $b_cxx_post" ;;
+      esac
+
+    cat >>Makefile.objects<<EOF
+$ac_bdir$ac_obj.lo: $ac_srcdir$ac_src
+	$ac_comp
+EOF
+  done
+
+
+
+
+  
+    BUILD_DIR="$BUILD_DIR sapi/cgi/fpm"
+  
+
+
+install_fpm="install-fpm"
+
+
+  echo "$ac_t""" 1>&6
+  echo "$ac_t""${T_MD}Configuring libevent${T_ME}" 1>&6
+
+
+test -d "$abs_builddir/libevent" || mkdir -p $abs_builddir/libevent
+
+
+chmod +x "$abs_srcdir/libevent/configure" \
+		"$abs_srcdir/libevent/depcomp" \
+		"$abs_srcdir/libevent/install-sh" \
+		"$abs_srcdir/libevent/missing"
+
+libevent_configure="cd $abs_builddir/libevent ; CFLAGS=\"$CFLAGS $GCC_CFLAGS\" $abs_srcdir/libevent/configure --disable-shared"
+
+(eval $libevent_configure)
+
+if test ! -f "$abs_builddir/libevent/Makefile" ; then
+	echo "Failed to configure libevent" >&2
+	exit 1
+fi
+
+
+LIBEVENT_LIBS="$LIBEVENT_LIBS `echo "@LIBS@" | $abs_builddir/libevent/config.status --file=-:-`"
+
+SAPI_EXTRA_LIBS="$LIBEVENT_LIBS $LIBXML_LIBS $JUDY_LIBS"
+
+
+if test "$prefix" = "NONE" ; then
+	fpm_prefix=/usr/local
+else
+	fpm_prefix="$prefix"
+fi
+
+if test "$PHP_FPM_CONF" = "\$prefix/etc/php-fpm.conf" ; then
+	php_fpm_conf_path="$fpm_prefix/etc/php-fpm.conf"
+else
+	php_fpm_conf_path="$PHP_FPM_CONF"
+fi
+
+if test "$PHP_FPM_LOG" = "\$prefix/logs/php-fpm.log" ; then
+	php_fpm_log_path="$fpm_prefix/logs/php-fpm.log"
+else
+	php_fpm_log_path="$PHP_FPM_LOG"
+fi
+
+if test "$PHP_FPM_PID" = "\$prefix/logs/php-fpm.pid" ; then
+	php_fpm_pid_path="$fpm_prefix/logs/php-fpm.pid"
+else
+	php_fpm_pid_path="$PHP_FPM_PID"
+fi
+
+
+if grep nobody /etc/group >/dev/null 2>&1; then
+	php_fpm_group=nobody
+else
+	if grep nogroup /etc/group >/dev/null 2>&1; then
+		php_fpm_group=nogroup
+	else
+		php_fpm_group=nobody
+	fi
+fi
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST php_fpm_conf_path"
+
+  
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST php_fpm_log_path"
+
+  
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST php_fpm_pid_path"
+
+  
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST php_fpm_group"
+
+  
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST FPM_VERSION"
+
+  
+
+
+
+  PHP_OUTPUT_FILES="$PHP_OUTPUT_FILES sapi/cgi/fpm/fpm_autoconf.h"
+
+
+  PHP_OUTPUT_FILES="$PHP_OUTPUT_FILES sapi/cgi/fpm/php-fpm.conf:sapi/cgi/fpm/conf/php-fpm.conf.in"
+
+
+  PHP_OUTPUT_FILES="$PHP_OUTPUT_FILES sapi/cgi/fpm/php-fpm:sapi/cgi/fpm/init.d/php-fpm.in"
+
+
+fi
+
 
 
 
@@ -17779,6 +18695,7 @@ fi
 for ac_func in alphasort \
 asctime_r \
 chroot \
+clearenv \
 ctime_r \
 cuserid \
 crypt \
@@ -108404,6 +109321,18 @@ fi
 
 
   
+  PHP_VAR_SUBST="$PHP_VAR_SUBST SAPI_EXTRA_LIBS"
+
+  
+
+
+  
+  PHP_VAR_SUBST="$PHP_VAR_SUBST SAPI_EXTRA_DEPS"
+
+  
+
+
+  
   PHP_VAR_SUBST="$PHP_VAR_SUBST ZEND_EXTRA_LIBS"
 
   
@@ -116677,7 +117606,7 @@ case $PHP_SAPI in
     install_targets="$PHP_INSTALL_CLI_TARGET $install_targets"
     ;;
   *)
-    install_targets="install-sapi $PHP_INSTALL_CLI_TARGET $install_targets"
+    install_targets="install-sapi $install_fpm $PHP_INSTALL_CLI_TARGET $install_targets"
     ;;
 esac
 
@@ -117381,6 +118310,12 @@ s%@LEX_OUTPUT_ROOT@%$LEX_OUTPUT_ROOT%g
 s%@RE2C@%$RE2C%g
 s%@SHLIB_SUFFIX_NAME@%$SHLIB_SUFFIX_NAME%g
 s%@SHLIB_DL_SUFFIX_NAME@%$SHLIB_DL_SUFFIX_NAME%g
+s%@XMLCONFIG@%$XMLCONFIG%g
+s%@php_fpm_conf_path@%$php_fpm_conf_path%g
+s%@php_fpm_log_path@%$php_fpm_log_path%g
+s%@php_fpm_pid_path@%$php_fpm_pid_path%g
+s%@php_fpm_group@%$php_fpm_group%g
+s%@FPM_VERSION@%$FPM_VERSION%g
 s%@PROG_SENDMAIL@%$PROG_SENDMAIL%g
 s%@LIBOBJS@%$LIBOBJS%g
 s%@ALLOCA@%$ALLOCA%g
@@ -117430,6 +118365,8 @@ s%@EXTENSION_DIR@%$EXTENSION_DIR%g
 s%@EXTRA_LDFLAGS@%$EXTRA_LDFLAGS%g
 s%@EXTRA_LDFLAGS_PROGRAM@%$EXTRA_LDFLAGS_PROGRAM%g
 s%@EXTRA_LIBS@%$EXTRA_LIBS%g
+s%@SAPI_EXTRA_LIBS@%$SAPI_EXTRA_LIBS%g
+s%@SAPI_EXTRA_DEPS@%$SAPI_EXTRA_DEPS%g
 s%@ZEND_EXTRA_LIBS@%$ZEND_EXTRA_LIBS%g
 s%@INCLUDES@%$INCLUDES%g
 s%@EXTRA_INCLUDES@%$EXTRA_INCLUDES%g
diff --git a/configure.in b/configure.in
index e181ac9..4424930 100644
--- a/configure.in
+++ b/configure.in
@@ -295,6 +295,12 @@ if test "$enable_maintainer_zts" = "yes"; then
   PTHREADS_FLAGS
 fi
 
+if test "$PHP_FASTCGI" = "yes" -a "$PHP_FPM" = "yes"; then
+  PHP_CONFIGURE_PART(Running FastCGI Process Manager checks)
+  sinclude(sapi/cgi/fpm/acinclude.m4)
+  sinclude(sapi/cgi/fpm/config.m4)
+fi
+
 divert(3)
 
 dnl ## In diversion 3 we check for compile-time options to the PHP
@@ -511,6 +517,7 @@ AC_CHECK_FUNCS(
 alphasort \
 asctime_r \
 chroot \
+clearenv \
 ctime_r \
 cuserid \
 crypt \
@@ -1253,6 +1260,8 @@ PHP_SUBST_OLD(EXTENSION_DIR)
 PHP_SUBST_OLD(EXTRA_LDFLAGS)
 PHP_SUBST_OLD(EXTRA_LDFLAGS_PROGRAM)
 PHP_SUBST_OLD(EXTRA_LIBS)
+PHP_SUBST_OLD(SAPI_EXTRA_LIBS)
+PHP_SUBST_OLD(SAPI_EXTRA_DEPS)
 PHP_SUBST_OLD(ZEND_EXTRA_LIBS)
 PHP_SUBST_OLD(INCLUDES)
 PHP_SUBST_OLD(EXTRA_INCLUDES)
@@ -1364,7 +1373,7 @@ case $PHP_SAPI in
     install_targets="$PHP_INSTALL_CLI_TARGET $install_targets"
     ;;
   *)
-    install_targets="install-sapi $PHP_INSTALL_CLI_TARGET $install_targets"
+    install_targets="install-sapi $install_fpm $PHP_INSTALL_CLI_TARGET $install_targets"
     ;;
 esac
 
diff --git a/libevent/ChangeLog b/libevent/ChangeLog
new file mode 100644
index 0000000..c592139
--- /dev/null
+++ b/libevent/ChangeLog
@@ -0,0 +1,154 @@
+Changes in 1.4.8-stable:
+ o Match the query in DNS replies to the query in the request; from Vsevolod Stakhov.
+ o Fix a merge problem in which name_from_addr returned pointers to the stack; found by Jiang Hong.
+ o Do not remove Accept-Encoding header
+	
+Changes in 1.4.7-stable:
+ o Fix a bug where headers arriving in multiple packets were not parsed; fix from Jiang Hong; test by me.
+	
+Changes in 1.4.6-stable:
+ o evutil.h now includes <stdarg.h> directly
+ o switch all uses of [v]snprintf over to evutil
+ o Correct handling of trailing headers in chunked replies; from Scott Lamb.
+ o Support multi-line HTTP headers; based on a patch from Moshe Litvin
+ o Reject negative Content-Length headers; anonymous bug report
+ o Detect CLOCK_MONOTONIC at runtime for evdns; anonymous bug report	
+ o Fix a bug where deleting signals with the kqueue backend would cause subsequent adds to fail
+ o Support multiple events listening on the same signal; make signals regular events that go on the same event queue; problem report by Alexander Drozdov.
+ o Deal with evbuffer_read() returning -1 on EINTR|EAGAIN; from Adam Langley.
+ o Fix a bug in which the DNS server would incorrectly set the type of a cname reply to a.
+ o Fix a bug where setting the timeout on a bufferevent would take not effect if the event was already pending.
+ o Fix a memory leak when using signals for some event bases; reported by Alexander Drozdov.
+ o Add libevent.vcproj file to distribution to help with Windows build.
+ o Fix a problem with epoll() and reinit; problem report by Alexander Drozdov.	
+ o Fix off-by-one errors in devpoll; from Ian Bell
+ o Make event_add not change any state if it fails; reported by Ian Bell.
+ o Do not warn on accept when errno is either EAGAIN or EINTR
+
+Changes in 1.4.5-stable:
+ o Fix connection keep-alive behavior for HTTP/1.0
+ o Fix use of freed memory in event_reinit; pointed out by Peter Postma
+ o Constify struct timeval * where possible; pointed out by Forest Wilkinson
+ o allow min_heap_erase to be called on removed members; from liusifan.
+ o Rename INPUT and OUTPUT to EVRPC_INPUT and EVRPC_OUTPUT.  Retain INPUT/OUTPUT aliases on on-win32 platforms for backwards compatibility.
+ o Do not use SO_REUSEADDR when connecting
+ o Fix Windows build
+ o Fix a bug in event_rpcgen when generated fixed-sized entries
+
+Changes in 1.4.4-stable:
+ o Correct the documentation on buffer printf functions.
+ o Don't warn on unimplemented epoll_create(): this isn't a problem, just a reason to fall back to poll or select.
+ o Correctly handle timeouts larger than 35 minutes on Linux with epoll.c.  This is probably a kernel defect, but we'll have to support old kernels anyway even if it gets fixed.
+ o Fix a potential stack corruption bug in tagging on 64-bit CPUs.
+ o expose bufferevent_setwatermark via header files and fix high watermark on read
+ o fix a bug in bufferevent read water marks and add a test for them
+ o introduce bufferevent_setcb and bufferevent_setfd to allow better manipulation of bufferevents
+ o use libevent's internal timercmp on all platforms, to avoid bugs on old platforms where timercmp(a,b,<=) is buggy.
+ o reduce system calls for getting current time by caching it.
+ o fix evhttp_bind_socket() so that multiple sockets can be bound by the same http server.
+ o Build test directory correctly with CPPFLAGS set.
+ o Fix build under Visual C++ 2005.
+ o Expose evhttp_accept_socket() API.
+ o Merge windows gettimeofday() replacement into a new evutil_gettimeofday() function.
+ o Fix autoconf script behavior on IRIX.
+ o Make sure winsock2.h include always comes before windows.h include.
+
+
+Changes in 1.4.3-stable:
+ o include Content-Length in reply for HTTP/1.0 requests with keep-alive
+ o Patch from Tani Hosokawa: make some functions in http.c threadsafe.
+ o Do not free the kqop file descriptor in other processes, also allow it to be 0; from Andrei Nigmatulin
+ o make event_rpcgen.py generate code include event-config.h; reported by Sam Banks.
+ o make event methods static so that they are not exported; from Andrei Nigmatulin
+ o make RPC replies use application/octet-stream as mime type
+ o do not delete uninitialized timeout event in evdns
+
+Changes in 1.4.2-rc:
+ o remove pending timeouts on event_base_free()
+ o also check EAGAIN for Solaris' event ports; from W.C.A. Wijngaards
+ o devpoll and evport need reinit; tested by W.C.A Wijngaards
+ o event_base_get_method; from Springande Ulv
+ o Send CRLF after each chunk in HTTP output, for compliance with RFC2626.  Patch from "propanbutan".  Fixes bug 1894184.
+ o Add a int64_t parsing function, with unit tests, so we can apply Scott Lamb's fix to allow large HTTP values.
+ o Use a 64-bit field to hold HTTP content-lengths.  Patch from Scott Lamb.
+ o Allow regression code to build even without Python installed
+ o remove NDEBUG ifdefs from evdns.c
+ o update documentation of event_loop and event_base_loop; from Tani Hosokawa.
+ o detect integer types properly on platforms without stdint.h
+ o Remove "AM_MAINTAINER_MODE" declaration in configure.in: now makefiles and configure should get re-generated automatically when Makefile.am or configure.in chanes.
+ o do not insert event into list when evsel->add fails
+
+Changes in 1.4.1-beta:
+ o free minheap on event_base_free(); from Christopher Layne
+ o debug cleanups in signal.c; from Christopher Layne
+ o provide event_base_new() that does not set the current_base global
+ o bufferevent_write now uses a const source argument; report from Charles Kerr
+ o better documentation for event_base_loopexit; from Scott Lamb.
+ o Make kqueue have the same behavior as other backends when a signal is caught between event_add() and event_loop().  Previously, it would catch and ignore such signals.
+ o Make kqueue restore signal handlers correctly when event_del() is called.
+ o provide event_reinit() to reintialize an event_base after fork
+ o small improvements to evhttp documentation
+ o always generate Date and Content-Length headers for HTTP/1.1 replies
+ o set the correct event base for HTTP close events
+ o New function, event_{base_}loopbreak.  Like event_loopexit, it makes an event loop stop executing and return.  Unlike event_loopexit, it keeps subsequent pending events from getting executed.  Patch from Scott Lamb
+ o Removed obsoleted recalc code
+ o pull setters/getters out of RPC structures into a base class to which we just need to store a pointer; this reduces the memory footprint of these structures.
+ o fix a bug with event_rpcgen for integers
+ o move EV_PERSIST handling out of the event backends
+ o support for 32-bit tag numbers in rpc structures; this is wire compatible, but changes the API slightly.
+ o prefix {encode,decode}_tag functions with evtag to avoid collisions
+ o Correctly handle DNS replies with no answers set (Fixes bug 1846282)
+ o The configure script now takes an --enable-gcc-warnigns option that turns on many optional gcc warnings.  (Nick has been building with these for a while, but they might be useful to other developers.)
+ o When building with GCC, use the "format" attribute to verify type correctness of calls to printf-like functions.
+ o removed linger from http server socket; reported by Ilya Martynov
+ o allow \r or \n individually to separate HTTP headers instead of the standard "\r\n"; from Charles Kerr.
+ o demote most http warnings to debug messages
+ o Fix Solaris compilation; from Magne Mahre
+ o Add a "Date" header to HTTP responses, as required by HTTP 1.1.
+ o Support specifying the local address of an evhttp_connection using set_local_address
+ o Fix a memory leak in which failed HTTP connections would not free the request object
+ o Make adding of array members in event_rpcgen more efficient, but doubling memory allocation
+ o Fix a memory leak in the DNS server
+ o Fix compilation when DNS_USE_OPENSSL_FOR_ID is enabled
+ o Fix buffer size and string generation in evdns_resolve_reverse_ipv6().
+ o Respond to nonstandard DNS queries with "NOTIMPL" rather than by ignoring them.
+ o In DNS responses, the CD flag should be preserved, not the TC flag.
+ o Fix http.c to compile properly with USE_DEBUG; from Christopher Layne
+ o Handle NULL timeouts correctly on Solaris; from Trond Norbye
+ o Recalculate pending events properly when reallocating event array on Solaris; from Trond Norbye
+ o Add Doxygen documentation to header files; from Mark Heily
+ o Add a evdns_set_transaction_id_fn() function to override the default
+   transaction ID generation code.
+ o Add an evutil module (with header evutil.h) to implement our standard cross-platform hacks, on the theory that somebody else would like to use them too.
+ o Fix signals implementation on windows.
+ o Fix http module on windows to close sockets properly.
+ o Make autogen.sh script run correctly on systems where /bin/sh isn't bash. (Patch from Trond Norbye, rewritten by Hagne Mahre and then Hannah Schroeter.)
+ o Skip calling gettime() in timeout_process if we are not in fact waiting for any events. (Patch from Trond Norbye)
+ o Make test subdirectory compile under mingw.
+ o Fix win32 buffer.c behavior so that it is correct for sockets (which do not like ReadFile and WriteFile).
+ o Make the test.sh script run unit tests for the evpoll method.
+ o Make the entire evdns.h header enclosed in "extern C" as appropriate.
+ o Fix implementation of strsep on platforms that lack it
+ o Fix implementation of getaddrinfo on platforms that lack it; mainly, this will make Windows http.c work better.  Original patch by Lubomir Marinov.
+ o Fix evport implementation: port_disassociate called on unassociated events resulting in bogus errors; more efficient memory management; from Trond Norbye and Prakash Sangappa
+ o support for hooks on rpc input and output; can be used to implement rpc independent processing such as compression or authentication.
+ o use a min heap instead of a red-black tree for timeouts; as a result finding the min is a O(1) operation now; from Maxim Yegorushkin
+ o associate an event base with an rpc pool
+ o added two additional libraries: libevent_core and libevent_extra in addition to the regular libevent.  libevent_core contains only the event core whereas libevent_extra contains dns, http and rpc support
+ o Begin using libtool's library versioning support correctly.  If we don't mess up, this will more or less guarantee binaries linked against old versions of libevent continue working when we make changes to libevent that do not break backward compatibility.
+ o Fix evhttp.h compilation when TAILQ_ENTRY is not defined.
+ o Small code cleanups in epoll_dispatch().
+ o Increase the maximum number of addresses read from a packet in evdns to 32.
+ o Remove support for the rtsig method: it hasn't compiled for a while, and nobody seems to miss it very much.  Let us know if there's a good reason to put it back in.
+ o Rename the "class" field in evdns_server_request to dns_question_class, so that it won't break compilation under C++.  Use a macro so that old code won't break.  Mark the macro as deprecated.
+ o Fix DNS unit tests so that having a DNS server with broken IPv6 support is no longer cause for aborting the unit tests.
+ o Make event_base_free() succeed even if there are pending non-internal events on a base.  This may still leak memory and fds, but at least it no longer crashes.
+ o Post-process the config.h file into a new, installed event-config.h file that we can install, and whose macros will be safe to include in header files.
+ o Remove the long-deprecated acconfig.h file.
+ o Do not require #include <sys/types.h> before #include <event.h>.
+ o Add new evutil_timer* functions to wrap (or replace) the regular timeval manipulation functions.
+ o Fix many build issues when using the Microsoft C compiler.
+ o Remove a bash-ism in autogen.sh
+ o When calling event_del on a signal, restore the signal handler's previous value rather than setting it to SIG_DFL. Patch from Christopher Layne.
+ o Make the logic for active events work better with internal events; patch from Christopher Layne.
+ o We do not need to specially remove a timeout before calling event_del; patch from Christopher Layne.
diff --git a/libevent/Makefile.am b/libevent/Makefile.am
new file mode 100644
index 0000000..5ccfd2c
--- /dev/null
+++ b/libevent/Makefile.am
@@ -0,0 +1,62 @@
+
+
+# This is the point release for libevent.  It shouldn't include any
+# a/b/c/d/e notations.
+RELEASE = 1.4
+
+# This is the version info for the libevent binary API.  It has three
+# numbers:
+#   Current  -- the number of the binary API that we're implementing
+#   Revision -- which iteration of the implementation of the binary
+#               API are we supplying?
+#   Age      -- How many previous binary API versions do we also
+#               support?
+#
+# If we release a new version that does not change the binary API,
+# increment Revision.
+#
+# If we release a new version that changes the binary API, but does
+# not break programs compiled against the old binary API, increment
+# Current and Age.  Set Revision to 0, since this is the first
+# implementation of the new API.
+#
+# Otherwise, we're changing the binary API and breaking bakward
+# compatibility with old binaries.  Increment Current.  Set Age to 0,
+# since we're backward compatible with no previous APIs.  Set Revision
+# to 0 too.
+
+# History:
+#  Libevent 1.4.1 was 2:0:0
+#  Libevent 1.4.2 should be 3:0:0
+#  Libevent 1.4.5 is 3:0:1 (we forgot to increment in the past)
+VERSION_INFO = 3:2:1
+
+noinst_LIBRARIES = libevent.a
+
+
+
+BUILT_SOURCES = event-config.h
+
+event-config.h: config.h
+	echo '/* event-config.h' > $@
+	echo ' * Generated by autoconf; post-processed by libevent.' >> $@
+	echo ' * Do not edit this file.' >> $@
+	echo ' * Do not rely on macros in this file existing in later versions.'>> $@
+	echo ' */' >> $@
+	echo '#ifndef _EVENT_CONFIG_H_' >> $@
+	echo '#define _EVENT_CONFIG_H_' >> $@
+
+	sed -e 's/#define /#define _EVENT_/' \
+	    -e 's/#undef /#undef _EVENT_/' \
+	    -e 's/#ifndef /#ifndef _EVENT_/' < config.h >> $@
+	echo "#endif" >> $@
+
+CORE_SRC = event.c log.c evutil.c http.c buffer.c evbuffer.c strlcpy.c $(SYS_SRC)
+
+libevent_a_SOURCES = $(CORE_SRC) $(EXTRA_SRC)
+libevent_a_DEPENDENCIES = $(LIBOBJS)
+libevent_a_LIBADD = $(LIBOBJS)
+
+include_HEADERS = event.h evutil.h event-config.h
+
+INCLUDES = -I$(srcdir)/compat $(SYS_INCLUDES)
diff --git a/libevent/Makefile.in b/libevent/Makefile.in
new file mode 100644
index 0000000..0600dcc
--- /dev/null
+++ b/libevent/Makefile.in
@@ -0,0 +1,618 @@
+# Makefile.in generated by automake 1.9.5 from Makefile.am.
+# @configure_input@
+
+# Copyright (C) 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002,
+# 2003, 2004, 2005  Free Software Foundation, Inc.
+# This Makefile.in is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# This program is distributed in the hope that it will be useful,
+# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
+# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
+# PARTICULAR PURPOSE.
+
+@SET_MAKE@
+
+
+SOURCES = $(libevent_a_SOURCES)
+
+srcdir = @srcdir@
+top_srcdir = @top_srcdir@
+VPATH = @srcdir@
+pkgdatadir = $(datadir)/@PACKAGE@
+pkglibdir = $(libdir)/@PACKAGE@
+pkgincludedir = $(includedir)/@PACKAGE@
+top_builddir = .
+am__cd = CDPATH="$${ZSH_VERSION+.}$(PATH_SEPARATOR)" && cd
+INSTALL = @INSTALL@
+install_sh_DATA = $(install_sh) -c -m 644
+install_sh_PROGRAM = $(install_sh) -c
+install_sh_SCRIPT = $(install_sh) -c
+INSTALL_HEADER = $(INSTALL_DATA)
+transform = $(program_transform_name)
+NORMAL_INSTALL = :
+PRE_INSTALL = :
+POST_INSTALL = :
+NORMAL_UNINSTALL = :
+PRE_UNINSTALL = :
+POST_UNINSTALL = :
+subdir = .
+DIST_COMMON = README $(am__configure_deps) $(include_HEADERS) \
+	$(srcdir)/Makefile.am $(srcdir)/Makefile.in \
+	$(srcdir)/config.h.in $(top_srcdir)/configure ChangeLog \
+	depcomp devpoll.c epoll.c epoll_sub.c evport.c install-sh \
+	kqueue.c missing poll.c select.c signal.c
+ACLOCAL_M4 = $(top_srcdir)/aclocal.m4
+am__aclocal_m4_deps = $(top_srcdir)/configure.in
+am__configure_deps = $(am__aclocal_m4_deps) $(CONFIGURE_DEPENDENCIES) \
+	$(ACLOCAL_M4)
+am__CONFIG_DISTCLEAN_FILES = config.status config.cache config.log \
+ configure.lineno configure.status.lineno
+mkinstalldirs = $(install_sh) -d
+CONFIG_HEADER = config.h
+CONFIG_CLEAN_FILES =
+LIBRARIES = $(noinst_LIBRARIES)
+AR = ar
+ARFLAGS = cru
+libevent_a_AR = $(AR) $(ARFLAGS)
+am__DEPENDENCIES_1 = @LIBOBJS@
+am__objects_1 = event.$(OBJEXT) log.$(OBJEXT) evutil.$(OBJEXT) \
+	http.$(OBJEXT) buffer.$(OBJEXT) evbuffer.$(OBJEXT) \
+	strlcpy.$(OBJEXT)
+am_libevent_a_OBJECTS = $(am__objects_1)
+libevent_a_OBJECTS = $(am_libevent_a_OBJECTS)
+DEFAULT_INCLUDES = -I. -I$(srcdir) -I.
+depcomp = $(SHELL) $(top_srcdir)/depcomp
+am__depfiles_maybe = depfiles
+COMPILE = $(CC) $(DEFS) $(DEFAULT_INCLUDES) $(INCLUDES) $(AM_CPPFLAGS) \
+	$(CPPFLAGS) $(AM_CFLAGS) $(CFLAGS)
+CCLD = $(CC)
+LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o $@
+SOURCES = $(libevent_a_SOURCES)
+DIST_SOURCES = $(libevent_a_SOURCES)
+am__vpath_adj_setup = srcdirstrip=`echo "$(srcdir)" | sed 's|.|.|g'`;
+am__vpath_adj = case $$p in \
+    $(srcdir)/*) f=`echo "$$p" | sed "s|^$$srcdirstrip/||"`;; \
+    *) f=$$p;; \
+  esac;
+am__strip_dir = `echo $$p | sed -e 's|^.*/||'`;
+am__installdirs = "$(DESTDIR)$(includedir)"
+includeHEADERS_INSTALL = $(INSTALL_HEADER)
+HEADERS = $(include_HEADERS)
+ETAGS = etags
+CTAGS = ctags
+DISTFILES = $(DIST_COMMON) $(DIST_SOURCES) $(TEXINFOS) $(EXTRA_DIST)
+distdir = $(PACKAGE)-$(VERSION)
+top_distdir = $(distdir)
+am__remove_distdir = \
+  { test ! -d $(distdir) \
+    || { find $(distdir) -type d ! -perm -200 -exec chmod u+w {} ';' \
+         && rm -fr $(distdir); }; }
+DIST_ARCHIVES = $(distdir).tar.gz
+GZIP_ENV = --best
+distuninstallcheck_listfiles = find . -type f -print
+distcleancheck_listfiles = find . -type f -print
+ACLOCAL = @ACLOCAL@
+AMDEP_FALSE = @AMDEP_FALSE@
+AMDEP_TRUE = @AMDEP_TRUE@
+AMTAR = @AMTAR@
+AUTOCONF = @AUTOCONF@
+AUTOHEADER = @AUTOHEADER@
+AUTOMAKE = @AUTOMAKE@
+AWK = @AWK@
+BUILD_WIN32_FALSE = @BUILD_WIN32_FALSE@
+BUILD_WIN32_TRUE = @BUILD_WIN32_TRUE@
+CC = @CC@
+CCDEPMODE = @CCDEPMODE@
+CFLAGS = @CFLAGS@
+CPP = @CPP@
+CPPFLAGS = @CPPFLAGS@
+CYGPATH_W = @CYGPATH_W@
+DEFS = @DEFS@
+DEPDIR = @DEPDIR@
+ECHO_C = @ECHO_C@
+ECHO_N = @ECHO_N@
+ECHO_T = @ECHO_T@
+EGREP = @EGREP@
+EXEEXT = @EXEEXT@
+INSTALL_DATA = @INSTALL_DATA@
+INSTALL_PROGRAM = @INSTALL_PROGRAM@
+INSTALL_SCRIPT = @INSTALL_SCRIPT@
+INSTALL_STRIP_PROGRAM = @INSTALL_STRIP_PROGRAM@
+LDFLAGS = @LDFLAGS@
+LIBOBJS = @LIBOBJS@
+LIBS = @LIBS@
+LN_S = @LN_S@
+LTLIBOBJS = @LTLIBOBJS@
+MAKEINFO = @MAKEINFO@
+OBJEXT = @OBJEXT@
+PACKAGE = @PACKAGE@
+PACKAGE_BUGREPORT = @PACKAGE_BUGREPORT@
+PACKAGE_NAME = @PACKAGE_NAME@
+PACKAGE_STRING = @PACKAGE_STRING@
+PACKAGE_TARNAME = @PACKAGE_TARNAME@
+PACKAGE_VERSION = @PACKAGE_VERSION@
+PATH_SEPARATOR = @PATH_SEPARATOR@
+RANLIB = @RANLIB@
+SET_MAKE = @SET_MAKE@
+SHELL = @SHELL@
+STRIP = @STRIP@
+VERSION = @VERSION@
+ac_ct_CC = @ac_ct_CC@
+ac_ct_RANLIB = @ac_ct_RANLIB@
+ac_ct_STRIP = @ac_ct_STRIP@
+am__fastdepCC_FALSE = @am__fastdepCC_FALSE@
+am__fastdepCC_TRUE = @am__fastdepCC_TRUE@
+am__include = @am__include@
+am__leading_dot = @am__leading_dot@
+am__quote = @am__quote@
+am__tar = @am__tar@
+am__untar = @am__untar@
+bindir = @bindir@
+build_alias = @build_alias@
+datadir = @datadir@
+exec_prefix = @exec_prefix@
+host_alias = @host_alias@
+includedir = @includedir@
+infodir = @infodir@
+install_sh = @install_sh@
+libdir = @libdir@
+libexecdir = @libexecdir@
+localstatedir = @localstatedir@
+mandir = @mandir@
+mkdir_p = @mkdir_p@
+oldincludedir = @oldincludedir@
+prefix = @prefix@
+program_transform_name = @program_transform_name@
+sbindir = @sbindir@
+sharedstatedir = @sharedstatedir@
+sysconfdir = @sysconfdir@
+target_alias = @target_alias@
+
+# This is the point release for libevent.  It shouldn't include any
+# a/b/c/d/e notations.
+RELEASE = 1.4
+
+# This is the version info for the libevent binary API.  It has three
+# numbers:
+#   Current  -- the number of the binary API that we're implementing
+#   Revision -- which iteration of the implementation of the binary
+#               API are we supplying?
+#   Age      -- How many previous binary API versions do we also
+#               support?
+#
+# If we release a new version that does not change the binary API,
+# increment Revision.
+#
+# If we release a new version that changes the binary API, but does
+# not break programs compiled against the old binary API, increment
+# Current and Age.  Set Revision to 0, since this is the first
+# implementation of the new API.
+#
+# Otherwise, we're changing the binary API and breaking bakward
+# compatibility with old binaries.  Increment Current.  Set Age to 0,
+# since we're backward compatible with no previous APIs.  Set Revision
+# to 0 too.
+
+# History:
+#  Libevent 1.4.1 was 2:0:0
+#  Libevent 1.4.2 should be 3:0:0
+#  Libevent 1.4.5 is 3:0:1 (we forgot to increment in the past)
+VERSION_INFO = 3:2:1
+noinst_LIBRARIES = libevent.a
+BUILT_SOURCES = event-config.h
+CORE_SRC = event.c log.c evutil.c http.c buffer.c evbuffer.c strlcpy.c $(SYS_SRC)
+libevent_a_SOURCES = $(CORE_SRC) $(EXTRA_SRC)
+libevent_a_DEPENDENCIES = $(LIBOBJS)
+libevent_a_LIBADD = $(LIBOBJS)
+include_HEADERS = event.h evutil.h event-config.h
+INCLUDES = -I$(srcdir)/compat $(SYS_INCLUDES)
+all: $(BUILT_SOURCES) config.h
+	$(MAKE) $(AM_MAKEFLAGS) all-am
+
+.SUFFIXES:
+.SUFFIXES: .c .o .obj
+am--refresh:
+	@:
+$(srcdir)/Makefile.in:  $(srcdir)/Makefile.am  $(am__configure_deps)
+	@for dep in $?; do \
+	  case '$(am__configure_deps)' in \
+	    *$$dep*) \
+	      echo ' cd $(srcdir) && $(AUTOMAKE) --foreign '; \
+	      cd $(srcdir) && $(AUTOMAKE) --foreign  \
+		&& exit 0; \
+	      exit 1;; \
+	  esac; \
+	done; \
+	echo ' cd $(top_srcdir) && $(AUTOMAKE) --foreign  Makefile'; \
+	cd $(top_srcdir) && \
+	  $(AUTOMAKE) --foreign  Makefile
+.PRECIOUS: Makefile
+Makefile: $(srcdir)/Makefile.in $(top_builddir)/config.status
+	@case '$?' in \
+	  *config.status*) \
+	    echo ' $(SHELL) ./config.status'; \
+	    $(SHELL) ./config.status;; \
+	  *) \
+	    echo ' cd $(top_builddir) && $(SHELL) ./config.status $@ $(am__depfiles_maybe)'; \
+	    cd $(top_builddir) && $(SHELL) ./config.status $@ $(am__depfiles_maybe);; \
+	esac;
+
+$(top_builddir)/config.status: $(top_srcdir)/configure $(CONFIG_STATUS_DEPENDENCIES)
+	$(SHELL) ./config.status --recheck
+
+$(top_srcdir)/configure:  $(am__configure_deps)
+	cd $(srcdir) && $(AUTOCONF)
+$(ACLOCAL_M4):  $(am__aclocal_m4_deps)
+	cd $(srcdir) && $(ACLOCAL) $(ACLOCAL_AMFLAGS)
+
+config.h: stamp-h1
+	@if test ! -f $@; then \
+	  rm -f stamp-h1; \
+	  $(MAKE) stamp-h1; \
+	else :; fi
+
+stamp-h1: $(srcdir)/config.h.in $(top_builddir)/config.status
+	@rm -f stamp-h1
+	cd $(top_builddir) && $(SHELL) ./config.status config.h
+$(srcdir)/config.h.in:  $(am__configure_deps) 
+	cd $(top_srcdir) && $(AUTOHEADER)
+	rm -f stamp-h1
+	touch $@
+
+distclean-hdr:
+	-rm -f config.h stamp-h1
+
+clean-noinstLIBRARIES:
+	-test -z "$(noinst_LIBRARIES)" || rm -f $(noinst_LIBRARIES)
+libevent.a: $(libevent_a_OBJECTS) $(libevent_a_DEPENDENCIES) 
+	-rm -f libevent.a
+	$(libevent_a_AR) libevent.a $(libevent_a_OBJECTS) $(libevent_a_LIBADD)
+	$(RANLIB) libevent.a
+
+mostlyclean-compile:
+	-rm -f *.$(OBJEXT)
+
+distclean-compile:
+	-rm -f *.tab.c
+
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/devpoll.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/epoll.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/epoll_sub.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/evport.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/kqueue.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/poll.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/select.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@$(DEPDIR)/signal.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/buffer.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/evbuffer.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/event.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/evutil.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/http.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/log.Po@am__quote@
+@AMDEP_TRUE@@am__include@ @am__quote@./$(DEPDIR)/strlcpy.Po@am__quote@
+
+.c.o:
+@am__fastdepCC_TRUE@	if $(COMPILE) -MT $@ -MD -MP -MF "$(DEPDIR)/$*.Tpo" -c -o $@ $<; \
+@am__fastdepCC_TRUE@	then mv -f "$(DEPDIR)/$*.Tpo" "$(DEPDIR)/$*.Po"; else rm -f "$(DEPDIR)/$*.Tpo"; exit 1; fi
+@AMDEP_TRUE@@am__fastdepCC_FALSE@	source='$<' object='$@' libtool=no @AMDEPBACKSLASH@
+@AMDEP_TRUE@@am__fastdepCC_FALSE@	DEPDIR=$(DEPDIR) $(CCDEPMODE) $(depcomp) @AMDEPBACKSLASH@
+@am__fastdepCC_FALSE@	$(COMPILE) -c $<
+
+.c.obj:
+@am__fastdepCC_TRUE@	if $(COMPILE) -MT $@ -MD -MP -MF "$(DEPDIR)/$*.Tpo" -c -o $@ `$(CYGPATH_W) '$<'`; \
+@am__fastdepCC_TRUE@	then mv -f "$(DEPDIR)/$*.Tpo" "$(DEPDIR)/$*.Po"; else rm -f "$(DEPDIR)/$*.Tpo"; exit 1; fi
+@AMDEP_TRUE@@am__fastdepCC_FALSE@	source='$<' object='$@' libtool=no @AMDEPBACKSLASH@
+@AMDEP_TRUE@@am__fastdepCC_FALSE@	DEPDIR=$(DEPDIR) $(CCDEPMODE) $(depcomp) @AMDEPBACKSLASH@
+@am__fastdepCC_FALSE@	$(COMPILE) -c `$(CYGPATH_W) '$<'`
+uninstall-info-am:
+install-includeHEADERS: $(include_HEADERS)
+	@$(NORMAL_INSTALL)
+	test -z "$(includedir)" || $(mkdir_p) "$(DESTDIR)$(includedir)"
+	@list='$(include_HEADERS)'; for p in $$list; do \
+	  if test -f "$$p"; then d=; else d="$(srcdir)/"; fi; \
+	  f=$(am__strip_dir) \
+	  echo " $(includeHEADERS_INSTALL) '$$d$$p' '$(DESTDIR)$(includedir)/$$f'"; \
+	  $(includeHEADERS_INSTALL) "$$d$$p" "$(DESTDIR)$(includedir)/$$f"; \
+	done
+
+uninstall-includeHEADERS:
+	@$(NORMAL_UNINSTALL)
+	@list='$(include_HEADERS)'; for p in $$list; do \
+	  f=$(am__strip_dir) \
+	  echo " rm -f '$(DESTDIR)$(includedir)/$$f'"; \
+	  rm -f "$(DESTDIR)$(includedir)/$$f"; \
+	done
+
+ID: $(HEADERS) $(SOURCES) $(LISP) $(TAGS_FILES)
+	list='$(SOURCES) $(HEADERS) $(LISP) $(TAGS_FILES)'; \
+	unique=`for i in $$list; do \
+	    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
+	  done | \
+	  $(AWK) '    { files[$$0] = 1; } \
+	       END { for (i in files) print i; }'`; \
+	mkid -fID $$unique
+tags: TAGS
+
+TAGS:  $(HEADERS) $(SOURCES) config.h.in $(TAGS_DEPENDENCIES) \
+		$(TAGS_FILES) $(LISP)
+	tags=; \
+	here=`pwd`; \
+	list='$(SOURCES) $(HEADERS) config.h.in $(LISP) $(TAGS_FILES)'; \
+	unique=`for i in $$list; do \
+	    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
+	  done | \
+	  $(AWK) '    { files[$$0] = 1; } \
+	       END { for (i in files) print i; }'`; \
+	if test -z "$(ETAGS_ARGS)$$tags$$unique"; then :; else \
+	  test -n "$$unique" || unique=$$empty_fix; \
+	  $(ETAGS) $(ETAGSFLAGS) $(AM_ETAGSFLAGS) $(ETAGS_ARGS) \
+	    $$tags $$unique; \
+	fi
+ctags: CTAGS
+CTAGS:  $(HEADERS) $(SOURCES) config.h.in $(TAGS_DEPENDENCIES) \
+		$(TAGS_FILES) $(LISP)
+	tags=; \
+	here=`pwd`; \
+	list='$(SOURCES) $(HEADERS) config.h.in $(LISP) $(TAGS_FILES)'; \
+	unique=`for i in $$list; do \
+	    if test -f "$$i"; then echo $$i; else echo $(srcdir)/$$i; fi; \
+	  done | \
+	  $(AWK) '    { files[$$0] = 1; } \
+	       END { for (i in files) print i; }'`; \
+	test -z "$(CTAGS_ARGS)$$tags$$unique" \
+	  || $(CTAGS) $(CTAGSFLAGS) $(AM_CTAGSFLAGS) $(CTAGS_ARGS) \
+	     $$tags $$unique
+
+GTAGS:
+	here=`$(am__cd) $(top_builddir) && pwd` \
+	  && cd $(top_srcdir) \
+	  && gtags -i $(GTAGS_ARGS) $$here
+
+distclean-tags:
+	-rm -f TAGS ID GTAGS GRTAGS GSYMS GPATH tags
+
+distdir: $(DISTFILES)
+	$(am__remove_distdir)
+	mkdir $(distdir)
+	@srcdirstrip=`echo "$(srcdir)" | sed 's|.|.|g'`; \
+	topsrcdirstrip=`echo "$(top_srcdir)" | sed 's|.|.|g'`; \
+	list='$(DISTFILES)'; for file in $$list; do \
+	  case $$file in \
+	    $(srcdir)/*) file=`echo "$$file" | sed "s|^$$srcdirstrip/||"`;; \
+	    $(top_srcdir)/*) file=`echo "$$file" | sed "s|^$$topsrcdirstrip/|$(top_builddir)/|"`;; \
+	  esac; \
+	  if test -f $$file || test -d $$file; then d=.; else d=$(srcdir); fi; \
+	  dir=`echo "$$file" | sed -e 's,/[^/]*$$,,'`; \
+	  if test "$$dir" != "$$file" && test "$$dir" != "."; then \
+	    dir="/$$dir"; \
+	    $(mkdir_p) "$(distdir)$$dir"; \
+	  else \
+	    dir=''; \
+	  fi; \
+	  if test -d $$d/$$file; then \
+	    if test -d $(srcdir)/$$file && test $$d != $(srcdir); then \
+	      cp -pR $(srcdir)/$$file $(distdir)$$dir || exit 1; \
+	    fi; \
+	    cp -pR $$d/$$file $(distdir)$$dir || exit 1; \
+	  else \
+	    test -f $(distdir)/$$file \
+	    || cp -p $$d/$$file $(distdir)/$$file \
+	    || exit 1; \
+	  fi; \
+	done
+	-find $(distdir) -type d ! -perm -777 -exec chmod a+rwx {} \; -o \
+	  ! -type d ! -perm -444 -links 1 -exec chmod a+r {} \; -o \
+	  ! -type d ! -perm -400 -exec chmod a+r {} \; -o \
+	  ! -type d ! -perm -444 -exec $(SHELL) $(install_sh) -c -m a+r {} {} \; \
+	|| chmod -R a+r $(distdir)
+dist-gzip: distdir
+	tardir=$(distdir) && $(am__tar) | GZIP=$(GZIP_ENV) gzip -c >$(distdir).tar.gz
+	$(am__remove_distdir)
+
+dist-bzip2: distdir
+	tardir=$(distdir) && $(am__tar) | bzip2 -9 -c >$(distdir).tar.bz2
+	$(am__remove_distdir)
+
+dist-tarZ: distdir
+	tardir=$(distdir) && $(am__tar) | compress -c >$(distdir).tar.Z
+	$(am__remove_distdir)
+
+dist-shar: distdir
+	shar $(distdir) | GZIP=$(GZIP_ENV) gzip -c >$(distdir).shar.gz
+	$(am__remove_distdir)
+
+dist-zip: distdir
+	-rm -f $(distdir).zip
+	zip -rq $(distdir).zip $(distdir)
+	$(am__remove_distdir)
+
+dist dist-all: distdir
+	tardir=$(distdir) && $(am__tar) | GZIP=$(GZIP_ENV) gzip -c >$(distdir).tar.gz
+	$(am__remove_distdir)
+
+# This target untars the dist file and tries a VPATH configuration.  Then
+# it guarantees that the distribution is self-contained by making another
+# tarfile.
+distcheck: dist
+	case '$(DIST_ARCHIVES)' in \
+	*.tar.gz*) \
+	  GZIP=$(GZIP_ENV) gunzip -c $(distdir).tar.gz | $(am__untar) ;;\
+	*.tar.bz2*) \
+	  bunzip2 -c $(distdir).tar.bz2 | $(am__untar) ;;\
+	*.tar.Z*) \
+	  uncompress -c $(distdir).tar.Z | $(am__untar) ;;\
+	*.shar.gz*) \
+	  GZIP=$(GZIP_ENV) gunzip -c $(distdir).shar.gz | unshar ;;\
+	*.zip*) \
+	  unzip $(distdir).zip ;;\
+	esac
+	chmod -R a-w $(distdir); chmod a+w $(distdir)
+	mkdir $(distdir)/_build
+	mkdir $(distdir)/_inst
+	chmod a-w $(distdir)
+	dc_install_base=`$(am__cd) $(distdir)/_inst && pwd | sed -e 's,^[^:\\/]:[\\/],/,'` \
+	  && dc_destdir="$${TMPDIR-/tmp}/am-dc-$$$$/" \
+	  && cd $(distdir)/_build \
+	  && ../configure --srcdir=.. --prefix="$$dc_install_base" \
+	    $(DISTCHECK_CONFIGURE_FLAGS) \
+	  && $(MAKE) $(AM_MAKEFLAGS) \
+	  && $(MAKE) $(AM_MAKEFLAGS) dvi \
+	  && $(MAKE) $(AM_MAKEFLAGS) check \
+	  && $(MAKE) $(AM_MAKEFLAGS) install \
+	  && $(MAKE) $(AM_MAKEFLAGS) installcheck \
+	  && $(MAKE) $(AM_MAKEFLAGS) uninstall \
+	  && $(MAKE) $(AM_MAKEFLAGS) distuninstallcheck_dir="$$dc_install_base" \
+	        distuninstallcheck \
+	  && chmod -R a-w "$$dc_install_base" \
+	  && ({ \
+	       (cd ../.. && umask 077 && mkdir "$$dc_destdir") \
+	       && $(MAKE) $(AM_MAKEFLAGS) DESTDIR="$$dc_destdir" install \
+	       && $(MAKE) $(AM_MAKEFLAGS) DESTDIR="$$dc_destdir" uninstall \
+	       && $(MAKE) $(AM_MAKEFLAGS) DESTDIR="$$dc_destdir" \
+	            distuninstallcheck_dir="$$dc_destdir" distuninstallcheck; \
+	      } || { rm -rf "$$dc_destdir"; exit 1; }) \
+	  && rm -rf "$$dc_destdir" \
+	  && $(MAKE) $(AM_MAKEFLAGS) dist \
+	  && rm -rf $(DIST_ARCHIVES) \
+	  && $(MAKE) $(AM_MAKEFLAGS) distcleancheck
+	$(am__remove_distdir)
+	@(echo "$(distdir) archives ready for distribution: "; \
+	  list='$(DIST_ARCHIVES)'; for i in $$list; do echo $$i; done) | \
+	  sed -e '1{h;s/./=/g;p;x;}' -e '$${p;x;}'
+distuninstallcheck:
+	@cd $(distuninstallcheck_dir) \
+	&& test `$(distuninstallcheck_listfiles) | wc -l` -le 1 \
+	   || { echo "ERROR: files left after uninstall:" ; \
+	        if test -n "$(DESTDIR)"; then \
+	          echo "  (check DESTDIR support)"; \
+	        fi ; \
+	        $(distuninstallcheck_listfiles) ; \
+	        exit 1; } >&2
+distcleancheck: distclean
+	@if test '$(srcdir)' = . ; then \
+	  echo "ERROR: distcleancheck can only run from a VPATH build" ; \
+	  exit 1 ; \
+	fi
+	@test `$(distcleancheck_listfiles) | wc -l` -eq 0 \
+	  || { echo "ERROR: files left in build directory after distclean:" ; \
+	       $(distcleancheck_listfiles) ; \
+	       exit 1; } >&2
+check-am: all-am
+check: $(BUILT_SOURCES)
+	$(MAKE) $(AM_MAKEFLAGS) check-am
+all-am: Makefile $(LIBRARIES) $(HEADERS) config.h
+installdirs:
+	for dir in "$(DESTDIR)$(includedir)"; do \
+	  test -z "$$dir" || $(mkdir_p) "$$dir"; \
+	done
+install: $(BUILT_SOURCES)
+	$(MAKE) $(AM_MAKEFLAGS) install-am
+install-exec: install-exec-am
+install-data: install-data-am
+uninstall: uninstall-am
+
+install-am: all-am
+	@$(MAKE) $(AM_MAKEFLAGS) install-exec-am install-data-am
+
+installcheck: installcheck-am
+install-strip:
+	$(MAKE) $(AM_MAKEFLAGS) INSTALL_PROGRAM="$(INSTALL_STRIP_PROGRAM)" \
+	  install_sh_PROGRAM="$(INSTALL_STRIP_PROGRAM)" INSTALL_STRIP_FLAG=-s \
+	  `test -z '$(STRIP)' || \
+	    echo "INSTALL_PROGRAM_ENV=STRIPPROG='$(STRIP)'"` install
+mostlyclean-generic:
+
+clean-generic:
+
+distclean-generic:
+	-test -z "$(CONFIG_CLEAN_FILES)" || rm -f $(CONFIG_CLEAN_FILES)
+
+maintainer-clean-generic:
+	@echo "This command is intended for maintainers to use"
+	@echo "it deletes files that may require special tools to rebuild."
+	-test -z "$(BUILT_SOURCES)" || rm -f $(BUILT_SOURCES)
+clean: clean-am
+
+clean-am: clean-generic clean-noinstLIBRARIES mostlyclean-am
+
+distclean: distclean-am
+	-rm -f $(am__CONFIG_DISTCLEAN_FILES)
+	-rm -rf $(DEPDIR) ./$(DEPDIR)
+	-rm -f Makefile
+distclean-am: clean-am distclean-compile distclean-generic \
+	distclean-hdr distclean-tags
+
+dvi: dvi-am
+
+dvi-am:
+
+html: html-am
+
+info: info-am
+
+info-am:
+
+install-data-am: install-includeHEADERS
+
+install-exec-am:
+
+install-info: install-info-am
+
+install-man:
+
+installcheck-am:
+
+maintainer-clean: maintainer-clean-am
+	-rm -f $(am__CONFIG_DISTCLEAN_FILES)
+	-rm -rf $(top_srcdir)/autom4te.cache
+	-rm -rf $(DEPDIR) ./$(DEPDIR)
+	-rm -f Makefile
+maintainer-clean-am: distclean-am maintainer-clean-generic
+
+mostlyclean: mostlyclean-am
+
+mostlyclean-am: mostlyclean-compile mostlyclean-generic
+
+pdf: pdf-am
+
+pdf-am:
+
+ps: ps-am
+
+ps-am:
+
+uninstall-am: uninstall-includeHEADERS uninstall-info-am
+
+.PHONY: CTAGS GTAGS all all-am am--refresh check check-am clean \
+	clean-generic clean-noinstLIBRARIES ctags dist dist-all \
+	dist-bzip2 dist-gzip dist-shar dist-tarZ dist-zip distcheck \
+	distclean distclean-compile distclean-generic distclean-hdr \
+	distclean-tags distcleancheck distdir distuninstallcheck dvi \
+	dvi-am html html-am info info-am install install-am \
+	install-data install-data-am install-exec install-exec-am \
+	install-includeHEADERS install-info install-info-am \
+	install-man install-strip installcheck installcheck-am \
+	installdirs maintainer-clean maintainer-clean-generic \
+	mostlyclean mostlyclean-compile mostlyclean-generic pdf pdf-am \
+	ps ps-am tags uninstall uninstall-am uninstall-includeHEADERS \
+	uninstall-info-am
+
+
+event-config.h: config.h
+	echo '/* event-config.h' > $@
+	echo ' * Generated by autoconf; post-processed by libevent.' >> $@
+	echo ' * Do not edit this file.' >> $@
+	echo ' * Do not rely on macros in this file existing in later versions.'>> $@
+	echo ' */' >> $@
+	echo '#ifndef _EVENT_CONFIG_H_' >> $@
+	echo '#define _EVENT_CONFIG_H_' >> $@
+
+	sed -e 's/#define /#define _EVENT_/' \
+	    -e 's/#undef /#undef _EVENT_/' \
+	    -e 's/#ifndef /#ifndef _EVENT_/' < config.h >> $@
+	echo "#endif" >> $@
+# Tell versions [3.59,3.63) of GNU make to not export all variables.
+# Otherwise a system limit (for SysV at least) may be exceeded.
+.NOEXPORT:
diff --git a/libevent/README b/libevent/README
new file mode 100644
index 0000000..b065039
--- /dev/null
+++ b/libevent/README
@@ -0,0 +1,57 @@
+To build libevent, type
+
+$ ./configure && make
+
+     (If you got libevent from the subversion repository, you will
+      first need to run the included "autogen.sh" script in order to
+      generate the configure script.)
+
+Install as root via
+
+# make install
+
+You can run the regression tests by
+
+$ make verify
+
+Before, reporting any problems, please run the regression tests.
+
+To enable the low-level tracing build the library as:
+
+CFLAGS=-DUSE_DEBUG ./configure [...]
+
+Acknowledgements:
+-----------------
+
+The following people have helped with suggestions, ideas, code or
+fixing bugs:
+
+  Alejo
+  Weston Andros Adamson
+  William Ahern
+  Stas Bekman
+  Andrew Danforth
+  Mike Davis
+  Shie Erlich
+  Alexander von Gernler
+  Artur Grabowski
+  Aaron Hopkins
+  Claudio Jeker
+  Scott Lamb
+  Adam Langley
+  Philip Lewis
+  David Libenzi
+  Nick Mathewson
+  Andrey Matveev
+  Richard Nyberg
+  Jon Oberheide
+  Phil Oleson
+  Dave Pacheco
+  Tassilo von Parseval
+  Pierre Phaneuf
+  Jon Poland
+  Bert JW Regeer
+  Dug Song
+  Taral
+
+If I have forgotten your name, please contact me.
diff --git a/libevent/aclocal.m4 b/libevent/aclocal.m4
new file mode 100644
index 0000000..74de4a1
--- /dev/null
+++ b/libevent/aclocal.m4
@@ -0,0 +1,862 @@
+# generated automatically by aclocal 1.9.5 -*- Autoconf -*-
+
+# Copyright (C) 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
+# 2005  Free Software Foundation, Inc.
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# This program is distributed in the hope that it will be useful,
+# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
+# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
+# PARTICULAR PURPOSE.
+
+# Copyright (C) 2002, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# AM_AUTOMAKE_VERSION(VERSION)
+# ----------------------------
+# Automake X.Y traces this macro to ensure aclocal.m4 has been
+# generated from the m4 files accompanying Automake X.Y.
+AC_DEFUN([AM_AUTOMAKE_VERSION], [am__api_version="1.9"])
+
+# AM_SET_CURRENT_AUTOMAKE_VERSION
+# -------------------------------
+# Call AM_AUTOMAKE_VERSION so it can be traced.
+# This function is AC_REQUIREd by AC_INIT_AUTOMAKE.
+AC_DEFUN([AM_SET_CURRENT_AUTOMAKE_VERSION],
+	 [AM_AUTOMAKE_VERSION([1.9.5])])
+
+# AM_AUX_DIR_EXPAND                                         -*- Autoconf -*-
+
+# Copyright (C) 2001, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# For projects using AC_CONFIG_AUX_DIR([foo]), Autoconf sets
+# $ac_aux_dir to `$srcdir/foo'.  In other projects, it is set to
+# `$srcdir', `$srcdir/..', or `$srcdir/../..'.
+#
+# Of course, Automake must honor this variable whenever it calls a
+# tool from the auxiliary directory.  The problem is that $srcdir (and
+# therefore $ac_aux_dir as well) can be either absolute or relative,
+# depending on how configure is run.  This is pretty annoying, since
+# it makes $ac_aux_dir quite unusable in subdirectories: in the top
+# source directory, any form will work fine, but in subdirectories a
+# relative path needs to be adjusted first.
+#
+# $ac_aux_dir/missing
+#    fails when called from a subdirectory if $ac_aux_dir is relative
+# $top_srcdir/$ac_aux_dir/missing
+#    fails if $ac_aux_dir is absolute,
+#    fails when called from a subdirectory in a VPATH build with
+#          a relative $ac_aux_dir
+#
+# The reason of the latter failure is that $top_srcdir and $ac_aux_dir
+# are both prefixed by $srcdir.  In an in-source build this is usually
+# harmless because $srcdir is `.', but things will broke when you
+# start a VPATH build or use an absolute $srcdir.
+#
+# So we could use something similar to $top_srcdir/$ac_aux_dir/missing,
+# iff we strip the leading $srcdir from $ac_aux_dir.  That would be:
+#   am_aux_dir='\$(top_srcdir)/'`expr "$ac_aux_dir" : "$srcdir//*\(.*\)"`
+# and then we would define $MISSING as
+#   MISSING="\${SHELL} $am_aux_dir/missing"
+# This will work as long as MISSING is not called from configure, because
+# unfortunately $(top_srcdir) has no meaning in configure.
+# However there are other variables, like CC, which are often used in
+# configure, and could therefore not use this "fixed" $ac_aux_dir.
+#
+# Another solution, used here, is to always expand $ac_aux_dir to an
+# absolute PATH.  The drawback is that using absolute paths prevent a
+# configured tree to be moved without reconfiguration.
+
+AC_DEFUN([AM_AUX_DIR_EXPAND],
+[dnl Rely on autoconf to set up CDPATH properly.
+AC_PREREQ([2.50])dnl
+# expand $ac_aux_dir to an absolute path
+am_aux_dir=`cd $ac_aux_dir && pwd`
+])
+
+# AM_CONDITIONAL                                            -*- Autoconf -*-
+
+# Copyright (C) 1997, 2000, 2001, 2003, 2004, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 7
+
+# AM_CONDITIONAL(NAME, SHELL-CONDITION)
+# -------------------------------------
+# Define a conditional.
+AC_DEFUN([AM_CONDITIONAL],
+[AC_PREREQ(2.52)dnl
+ ifelse([$1], [TRUE],  [AC_FATAL([$0: invalid condition: $1])],
+	[$1], [FALSE], [AC_FATAL([$0: invalid condition: $1])])dnl
+AC_SUBST([$1_TRUE])
+AC_SUBST([$1_FALSE])
+if $2; then
+  $1_TRUE=
+  $1_FALSE='#'
+else
+  $1_TRUE='#'
+  $1_FALSE=
+fi
+AC_CONFIG_COMMANDS_PRE(
+[if test -z "${$1_TRUE}" && test -z "${$1_FALSE}"; then
+  AC_MSG_ERROR([[conditional "$1" was never defined.
+Usually this means the macro was only invoked conditionally.]])
+fi])])
+
+
+# Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 8
+
+# There are a few dirty hacks below to avoid letting `AC_PROG_CC' be
+# written in clear, in which case automake, when reading aclocal.m4,
+# will think it sees a *use*, and therefore will trigger all it's
+# C support machinery.  Also note that it means that autoscan, seeing
+# CC etc. in the Makefile, will ask for an AC_PROG_CC use...
+
+
+# _AM_DEPENDENCIES(NAME)
+# ----------------------
+# See how the compiler implements dependency checking.
+# NAME is "CC", "CXX", "GCJ", or "OBJC".
+# We try a few techniques and use that to set a single cache variable.
+#
+# We don't AC_REQUIRE the corresponding AC_PROG_CC since the latter was
+# modified to invoke _AM_DEPENDENCIES(CC); we would have a circular
+# dependency, and given that the user is not expected to run this macro,
+# just rely on AC_PROG_CC.
+AC_DEFUN([_AM_DEPENDENCIES],
+[AC_REQUIRE([AM_SET_DEPDIR])dnl
+AC_REQUIRE([AM_OUTPUT_DEPENDENCY_COMMANDS])dnl
+AC_REQUIRE([AM_MAKE_INCLUDE])dnl
+AC_REQUIRE([AM_DEP_TRACK])dnl
+
+ifelse([$1], CC,   [depcc="$CC"   am_compiler_list=],
+       [$1], CXX,  [depcc="$CXX"  am_compiler_list=],
+       [$1], OBJC, [depcc="$OBJC" am_compiler_list='gcc3 gcc'],
+       [$1], GCJ,  [depcc="$GCJ"  am_compiler_list='gcc3 gcc'],
+                   [depcc="$$1"   am_compiler_list=])
+
+AC_CACHE_CHECK([dependency style of $depcc],
+               [am_cv_$1_dependencies_compiler_type],
+[if test -z "$AMDEP_TRUE" && test -f "$am_depcomp"; then
+  # We make a subdir and do the tests there.  Otherwise we can end up
+  # making bogus files that we don't know about and never remove.  For
+  # instance it was reported that on HP-UX the gcc test will end up
+  # making a dummy file named `D' -- because `-MD' means `put the output
+  # in D'.
+  mkdir conftest.dir
+  # Copy depcomp to subdir because otherwise we won't find it if we're
+  # using a relative directory.
+  cp "$am_depcomp" conftest.dir
+  cd conftest.dir
+  # We will build objects and dependencies in a subdirectory because
+  # it helps to detect inapplicable dependency modes.  For instance
+  # both Tru64's cc and ICC support -MD to output dependencies as a
+  # side effect of compilation, but ICC will put the dependencies in
+  # the current directory while Tru64 will put them in the object
+  # directory.
+  mkdir sub
+
+  am_cv_$1_dependencies_compiler_type=none
+  if test "$am_compiler_list" = ""; then
+     am_compiler_list=`sed -n ['s/^#*\([a-zA-Z0-9]*\))$/\1/p'] < ./depcomp`
+  fi
+  for depmode in $am_compiler_list; do
+    # Setup a source with many dependencies, because some compilers
+    # like to wrap large dependency lists on column 80 (with \), and
+    # we should not choose a depcomp mode which is confused by this.
+    #
+    # We need to recreate these files for each test, as the compiler may
+    # overwrite some of them when testing with obscure command lines.
+    # This happens at least with the AIX C compiler.
+    : > sub/conftest.c
+    for i in 1 2 3 4 5 6; do
+      echo '#include "conftst'$i'.h"' >> sub/conftest.c
+      # Using `: > sub/conftst$i.h' creates only sub/conftst1.h with
+      # Solaris 8's {/usr,}/bin/sh.
+      touch sub/conftst$i.h
+    done
+    echo "${am__include} ${am__quote}sub/conftest.Po${am__quote}" > confmf
+
+    case $depmode in
+    nosideeffect)
+      # after this tag, mechanisms are not by side-effect, so they'll
+      # only be used when explicitly requested
+      if test "x$enable_dependency_tracking" = xyes; then
+	continue
+      else
+	break
+      fi
+      ;;
+    none) break ;;
+    esac
+    # We check with `-c' and `-o' for the sake of the "dashmstdout"
+    # mode.  It turns out that the SunPro C++ compiler does not properly
+    # handle `-M -o', and we need to detect this.
+    if depmode=$depmode \
+       source=sub/conftest.c object=sub/conftest.${OBJEXT-o} \
+       depfile=sub/conftest.Po tmpdepfile=sub/conftest.TPo \
+       $SHELL ./depcomp $depcc -c -o sub/conftest.${OBJEXT-o} sub/conftest.c \
+         >/dev/null 2>conftest.err &&
+       grep sub/conftst6.h sub/conftest.Po > /dev/null 2>&1 &&
+       grep sub/conftest.${OBJEXT-o} sub/conftest.Po > /dev/null 2>&1 &&
+       ${MAKE-make} -s -f confmf > /dev/null 2>&1; then
+      # icc doesn't choke on unknown options, it will just issue warnings
+      # or remarks (even with -Werror).  So we grep stderr for any message
+      # that says an option was ignored or not supported.
+      # When given -MP, icc 7.0 and 7.1 complain thusly:
+      #   icc: Command line warning: ignoring option '-M'; no argument required
+      # The diagnosis changed in icc 8.0:
+      #   icc: Command line remark: option '-MP' not supported
+      if (grep 'ignoring option' conftest.err ||
+          grep 'not supported' conftest.err) >/dev/null 2>&1; then :; else
+        am_cv_$1_dependencies_compiler_type=$depmode
+        break
+      fi
+    fi
+  done
+
+  cd ..
+  rm -rf conftest.dir
+else
+  am_cv_$1_dependencies_compiler_type=none
+fi
+])
+AC_SUBST([$1DEPMODE], [depmode=$am_cv_$1_dependencies_compiler_type])
+AM_CONDITIONAL([am__fastdep$1], [
+  test "x$enable_dependency_tracking" != xno \
+  && test "$am_cv_$1_dependencies_compiler_type" = gcc3])
+])
+
+
+# AM_SET_DEPDIR
+# -------------
+# Choose a directory name for dependency files.
+# This macro is AC_REQUIREd in _AM_DEPENDENCIES
+AC_DEFUN([AM_SET_DEPDIR],
+[AC_REQUIRE([AM_SET_LEADING_DOT])dnl
+AC_SUBST([DEPDIR], ["${am__leading_dot}deps"])dnl
+])
+
+
+# AM_DEP_TRACK
+# ------------
+AC_DEFUN([AM_DEP_TRACK],
+[AC_ARG_ENABLE(dependency-tracking,
+[  --disable-dependency-tracking  speeds up one-time build
+  --enable-dependency-tracking   do not reject slow dependency extractors])
+if test "x$enable_dependency_tracking" != xno; then
+  am_depcomp="$ac_aux_dir/depcomp"
+  AMDEPBACKSLASH='\'
+fi
+AM_CONDITIONAL([AMDEP], [test "x$enable_dependency_tracking" != xno])
+AC_SUBST([AMDEPBACKSLASH])
+])
+
+# Generate code to set up dependency tracking.              -*- Autoconf -*-
+
+# Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+#serial 3
+
+# _AM_OUTPUT_DEPENDENCY_COMMANDS
+# ------------------------------
+AC_DEFUN([_AM_OUTPUT_DEPENDENCY_COMMANDS],
+[for mf in $CONFIG_FILES; do
+  # Strip MF so we end up with the name of the file.
+  mf=`echo "$mf" | sed -e 's/:.*$//'`
+  # Check whether this is an Automake generated Makefile or not.
+  # We used to match only the files named `Makefile.in', but
+  # some people rename them; so instead we look at the file content.
+  # Grep'ing the first line is not enough: some people post-process
+  # each Makefile.in and add a new line on top of each file to say so.
+  # So let's grep whole file.
+  if grep '^#.*generated by automake' $mf > /dev/null 2>&1; then
+    dirpart=`AS_DIRNAME("$mf")`
+  else
+    continue
+  fi
+  # Extract the definition of DEPDIR, am__include, and am__quote
+  # from the Makefile without running `make'.
+  DEPDIR=`sed -n 's/^DEPDIR = //p' < "$mf"`
+  test -z "$DEPDIR" && continue
+  am__include=`sed -n 's/^am__include = //p' < "$mf"`
+  test -z "am__include" && continue
+  am__quote=`sed -n 's/^am__quote = //p' < "$mf"`
+  # When using ansi2knr, U may be empty or an underscore; expand it
+  U=`sed -n 's/^U = //p' < "$mf"`
+  # Find all dependency output files, they are included files with
+  # $(DEPDIR) in their names.  We invoke sed twice because it is the
+  # simplest approach to changing $(DEPDIR) to its actual value in the
+  # expansion.
+  for file in `sed -n "
+    s/^$am__include $am__quote\(.*(DEPDIR).*\)$am__quote"'$/\1/p' <"$mf" | \
+       sed -e 's/\$(DEPDIR)/'"$DEPDIR"'/g' -e 's/\$U/'"$U"'/g'`; do
+    # Make sure the directory exists.
+    test -f "$dirpart/$file" && continue
+    fdir=`AS_DIRNAME(["$file"])`
+    AS_MKDIR_P([$dirpart/$fdir])
+    # echo "creating $dirpart/$file"
+    echo '# dummy' > "$dirpart/$file"
+  done
+done
+])# _AM_OUTPUT_DEPENDENCY_COMMANDS
+
+
+# AM_OUTPUT_DEPENDENCY_COMMANDS
+# -----------------------------
+# This macro should only be invoked once -- use via AC_REQUIRE.
+#
+# This code is only required when automatic dependency tracking
+# is enabled.  FIXME.  This creates each `.P' file that we will
+# need in order to bootstrap the dependency handling code.
+AC_DEFUN([AM_OUTPUT_DEPENDENCY_COMMANDS],
+[AC_CONFIG_COMMANDS([depfiles],
+     [test x"$AMDEP_TRUE" != x"" || _AM_OUTPUT_DEPENDENCY_COMMANDS],
+     [AMDEP_TRUE="$AMDEP_TRUE" ac_aux_dir="$ac_aux_dir"])
+])
+
+# Copyright (C) 1996, 1997, 2000, 2001, 2003, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 8
+
+# AM_CONFIG_HEADER is obsolete.  It has been replaced by AC_CONFIG_HEADERS.
+AU_DEFUN([AM_CONFIG_HEADER], [AC_CONFIG_HEADERS($@)])
+
+# Do all the work for Automake.                             -*- Autoconf -*-
+
+# Copyright (C) 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 12
+
+# This macro actually does too much.  Some checks are only needed if
+# your package does certain things.  But this isn't really a big deal.
+
+# AM_INIT_AUTOMAKE(PACKAGE, VERSION, [NO-DEFINE])
+# AM_INIT_AUTOMAKE([OPTIONS])
+# -----------------------------------------------
+# The call with PACKAGE and VERSION arguments is the old style
+# call (pre autoconf-2.50), which is being phased out.  PACKAGE
+# and VERSION should now be passed to AC_INIT and removed from
+# the call to AM_INIT_AUTOMAKE.
+# We support both call styles for the transition.  After
+# the next Automake release, Autoconf can make the AC_INIT
+# arguments mandatory, and then we can depend on a new Autoconf
+# release and drop the old call support.
+AC_DEFUN([AM_INIT_AUTOMAKE],
+[AC_PREREQ([2.58])dnl
+dnl Autoconf wants to disallow AM_ names.  We explicitly allow
+dnl the ones we care about.
+m4_pattern_allow([^AM_[A-Z]+FLAGS$])dnl
+AC_REQUIRE([AM_SET_CURRENT_AUTOMAKE_VERSION])dnl
+AC_REQUIRE([AC_PROG_INSTALL])dnl
+# test to see if srcdir already configured
+if test "`cd $srcdir && pwd`" != "`pwd`" &&
+   test -f $srcdir/config.status; then
+  AC_MSG_ERROR([source directory already configured; run "make distclean" there first])
+fi
+
+# test whether we have cygpath
+if test -z "$CYGPATH_W"; then
+  if (cygpath --version) >/dev/null 2>/dev/null; then
+    CYGPATH_W='cygpath -w'
+  else
+    CYGPATH_W=echo
+  fi
+fi
+AC_SUBST([CYGPATH_W])
+
+# Define the identity of the package.
+dnl Distinguish between old-style and new-style calls.
+m4_ifval([$2],
+[m4_ifval([$3], [_AM_SET_OPTION([no-define])])dnl
+ AC_SUBST([PACKAGE], [$1])dnl
+ AC_SUBST([VERSION], [$2])],
+[_AM_SET_OPTIONS([$1])dnl
+ AC_SUBST([PACKAGE], ['AC_PACKAGE_TARNAME'])dnl
+ AC_SUBST([VERSION], ['AC_PACKAGE_VERSION'])])dnl
+
+_AM_IF_OPTION([no-define],,
+[AC_DEFINE_UNQUOTED(PACKAGE, "$PACKAGE", [Name of package])
+ AC_DEFINE_UNQUOTED(VERSION, "$VERSION", [Version number of package])])dnl
+
+# Some tools Automake needs.
+AC_REQUIRE([AM_SANITY_CHECK])dnl
+AC_REQUIRE([AC_ARG_PROGRAM])dnl
+AM_MISSING_PROG(ACLOCAL, aclocal-${am__api_version})
+AM_MISSING_PROG(AUTOCONF, autoconf)
+AM_MISSING_PROG(AUTOMAKE, automake-${am__api_version})
+AM_MISSING_PROG(AUTOHEADER, autoheader)
+AM_MISSING_PROG(MAKEINFO, makeinfo)
+AM_PROG_INSTALL_SH
+AM_PROG_INSTALL_STRIP
+AC_REQUIRE([AM_PROG_MKDIR_P])dnl
+# We need awk for the "check" target.  The system "awk" is bad on
+# some platforms.
+AC_REQUIRE([AC_PROG_AWK])dnl
+AC_REQUIRE([AC_PROG_MAKE_SET])dnl
+AC_REQUIRE([AM_SET_LEADING_DOT])dnl
+_AM_IF_OPTION([tar-ustar], [_AM_PROG_TAR([ustar])],
+              [_AM_IF_OPTION([tar-pax], [_AM_PROG_TAR([pax])],
+	      		     [_AM_PROG_TAR([v7])])])
+_AM_IF_OPTION([no-dependencies],,
+[AC_PROVIDE_IFELSE([AC_PROG_CC],
+                  [_AM_DEPENDENCIES(CC)],
+                  [define([AC_PROG_CC],
+                          defn([AC_PROG_CC])[_AM_DEPENDENCIES(CC)])])dnl
+AC_PROVIDE_IFELSE([AC_PROG_CXX],
+                  [_AM_DEPENDENCIES(CXX)],
+                  [define([AC_PROG_CXX],
+                          defn([AC_PROG_CXX])[_AM_DEPENDENCIES(CXX)])])dnl
+])
+])
+
+
+# When config.status generates a header, we must update the stamp-h file.
+# This file resides in the same directory as the config header
+# that is generated.  The stamp files are numbered to have different names.
+
+# Autoconf calls _AC_AM_CONFIG_HEADER_HOOK (when defined) in the
+# loop where config.status creates the headers, so we can generate
+# our stamp files there.
+AC_DEFUN([_AC_AM_CONFIG_HEADER_HOOK],
+[# Compute $1's index in $config_headers.
+_am_stamp_count=1
+for _am_header in $config_headers :; do
+  case $_am_header in
+    $1 | $1:* )
+      break ;;
+    * )
+      _am_stamp_count=`expr $_am_stamp_count + 1` ;;
+  esac
+done
+echo "timestamp for $1" >`AS_DIRNAME([$1])`/stamp-h[]$_am_stamp_count])
+
+# Copyright (C) 2001, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# AM_PROG_INSTALL_SH
+# ------------------
+# Define $install_sh.
+AC_DEFUN([AM_PROG_INSTALL_SH],
+[AC_REQUIRE([AM_AUX_DIR_EXPAND])dnl
+install_sh=${install_sh-"$am_aux_dir/install-sh"}
+AC_SUBST(install_sh)])
+
+# Copyright (C) 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 2
+
+# Check whether the underlying file-system supports filenames
+# with a leading dot.  For instance MS-DOS doesn't.
+AC_DEFUN([AM_SET_LEADING_DOT],
+[rm -rf .tst 2>/dev/null
+mkdir .tst 2>/dev/null
+if test -d .tst; then
+  am__leading_dot=.
+else
+  am__leading_dot=_
+fi
+rmdir .tst 2>/dev/null
+AC_SUBST([am__leading_dot])])
+
+# Check to see how 'make' treats includes.	            -*- Autoconf -*-
+
+# Copyright (C) 2001, 2002, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 3
+
+# AM_MAKE_INCLUDE()
+# -----------------
+# Check to see how make treats includes.
+AC_DEFUN([AM_MAKE_INCLUDE],
+[am_make=${MAKE-make}
+cat > confinc << 'END'
+am__doit:
+	@echo done
+.PHONY: am__doit
+END
+# If we don't find an include directive, just comment out the code.
+AC_MSG_CHECKING([for style of include used by $am_make])
+am__include="#"
+am__quote=
+_am_result=none
+# First try GNU make style include.
+echo "include confinc" > confmf
+# We grep out `Entering directory' and `Leaving directory'
+# messages which can occur if `w' ends up in MAKEFLAGS.
+# In particular we don't look at `^make:' because GNU make might
+# be invoked under some other name (usually "gmake"), in which
+# case it prints its new name instead of `make'.
+if test "`$am_make -s -f confmf 2> /dev/null | grep -v 'ing directory'`" = "done"; then
+   am__include=include
+   am__quote=
+   _am_result=GNU
+fi
+# Now try BSD make style include.
+if test "$am__include" = "#"; then
+   echo '.include "confinc"' > confmf
+   if test "`$am_make -s -f confmf 2> /dev/null`" = "done"; then
+      am__include=.include
+      am__quote="\""
+      _am_result=BSD
+   fi
+fi
+AC_SUBST([am__include])
+AC_SUBST([am__quote])
+AC_MSG_RESULT([$_am_result])
+rm -f confinc confmf
+])
+
+# Fake the existence of programs that GNU maintainers use.  -*- Autoconf -*-
+
+# Copyright (C) 1997, 1999, 2000, 2001, 2003, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 4
+
+# AM_MISSING_PROG(NAME, PROGRAM)
+# ------------------------------
+AC_DEFUN([AM_MISSING_PROG],
+[AC_REQUIRE([AM_MISSING_HAS_RUN])
+$1=${$1-"${am_missing_run}$2"}
+AC_SUBST($1)])
+
+
+# AM_MISSING_HAS_RUN
+# ------------------
+# Define MISSING if not defined so far and test if it supports --run.
+# If it does, set am_missing_run to use it, otherwise, to nothing.
+AC_DEFUN([AM_MISSING_HAS_RUN],
+[AC_REQUIRE([AM_AUX_DIR_EXPAND])dnl
+test x"${MISSING+set}" = xset || MISSING="\${SHELL} $am_aux_dir/missing"
+# Use eval to expand $SHELL
+if eval "$MISSING --run true"; then
+  am_missing_run="$MISSING --run "
+else
+  am_missing_run=
+  AC_MSG_WARN([`missing' script is too old or missing])
+fi
+])
+
+# Copyright (C) 2003, 2004, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# AM_PROG_MKDIR_P
+# ---------------
+# Check whether `mkdir -p' is supported, fallback to mkinstalldirs otherwise.
+#
+# Automake 1.8 used `mkdir -m 0755 -p --' to ensure that directories
+# created by `make install' are always world readable, even if the
+# installer happens to have an overly restrictive umask (e.g. 077).
+# This was a mistake.  There are at least two reasons why we must not
+# use `-m 0755':
+#   - it causes special bits like SGID to be ignored,
+#   - it may be too restrictive (some setups expect 775 directories).
+#
+# Do not use -m 0755 and let people choose whatever they expect by
+# setting umask.
+#
+# We cannot accept any implementation of `mkdir' that recognizes `-p'.
+# Some implementations (such as Solaris 8's) are not thread-safe: if a
+# parallel make tries to run `mkdir -p a/b' and `mkdir -p a/c'
+# concurrently, both version can detect that a/ is missing, but only
+# one can create it and the other will error out.  Consequently we
+# restrict ourselves to GNU make (using the --version option ensures
+# this.)
+AC_DEFUN([AM_PROG_MKDIR_P],
+[if mkdir -p --version . >/dev/null 2>&1 && test ! -d ./--version; then
+  # We used to keeping the `.' as first argument, in order to
+  # allow $(mkdir_p) to be used without argument.  As in
+  #   $(mkdir_p) $(somedir)
+  # where $(somedir) is conditionally defined.  However this is wrong
+  # for two reasons:
+  #  1. if the package is installed by a user who cannot write `.'
+  #     make install will fail,
+  #  2. the above comment should most certainly read
+  #     $(mkdir_p) $(DESTDIR)$(somedir)
+  #     so it does not work when $(somedir) is undefined and
+  #     $(DESTDIR) is not.
+  #  To support the latter case, we have to write
+  #     test -z "$(somedir)" || $(mkdir_p) $(DESTDIR)$(somedir),
+  #  so the `.' trick is pointless.
+  mkdir_p='mkdir -p --'
+else
+  # On NextStep and OpenStep, the `mkdir' command does not
+  # recognize any option.  It will interpret all options as
+  # directories to create, and then abort because `.' already
+  # exists.
+  for d in ./-p ./--version;
+  do
+    test -d $d && rmdir $d
+  done
+  # $(mkinstalldirs) is defined by Automake if mkinstalldirs exists.
+  if test -f "$ac_aux_dir/mkinstalldirs"; then
+    mkdir_p='$(mkinstalldirs)'
+  else
+    mkdir_p='$(install_sh) -d'
+  fi
+fi
+AC_SUBST([mkdir_p])])
+
+# Helper functions for option handling.                     -*- Autoconf -*-
+
+# Copyright (C) 2001, 2002, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 3
+
+# _AM_MANGLE_OPTION(NAME)
+# -----------------------
+AC_DEFUN([_AM_MANGLE_OPTION],
+[[_AM_OPTION_]m4_bpatsubst($1, [[^a-zA-Z0-9_]], [_])])
+
+# _AM_SET_OPTION(NAME)
+# ------------------------------
+# Set option NAME.  Presently that only means defining a flag for this option.
+AC_DEFUN([_AM_SET_OPTION],
+[m4_define(_AM_MANGLE_OPTION([$1]), 1)])
+
+# _AM_SET_OPTIONS(OPTIONS)
+# ----------------------------------
+# OPTIONS is a space-separated list of Automake options.
+AC_DEFUN([_AM_SET_OPTIONS],
+[AC_FOREACH([_AM_Option], [$1], [_AM_SET_OPTION(_AM_Option)])])
+
+# _AM_IF_OPTION(OPTION, IF-SET, [IF-NOT-SET])
+# -------------------------------------------
+# Execute IF-SET if OPTION is set, IF-NOT-SET otherwise.
+AC_DEFUN([_AM_IF_OPTION],
+[m4_ifset(_AM_MANGLE_OPTION([$1]), [$2], [$3])])
+
+# Check to make sure that the build environment is sane.    -*- Autoconf -*-
+
+# Copyright (C) 1996, 1997, 2000, 2001, 2003, 2005
+# Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 4
+
+# AM_SANITY_CHECK
+# ---------------
+AC_DEFUN([AM_SANITY_CHECK],
+[AC_MSG_CHECKING([whether build environment is sane])
+# Just in case
+sleep 1
+echo timestamp > conftest.file
+# Do `set' in a subshell so we don't clobber the current shell's
+# arguments.  Must try -L first in case configure is actually a
+# symlink; some systems play weird games with the mod time of symlinks
+# (eg FreeBSD returns the mod time of the symlink's containing
+# directory).
+if (
+   set X `ls -Lt $srcdir/configure conftest.file 2> /dev/null`
+   if test "$[*]" = "X"; then
+      # -L didn't work.
+      set X `ls -t $srcdir/configure conftest.file`
+   fi
+   rm -f conftest.file
+   if test "$[*]" != "X $srcdir/configure conftest.file" \
+      && test "$[*]" != "X conftest.file $srcdir/configure"; then
+
+      # If neither matched, then we have a broken ls.  This can happen
+      # if, for instance, CONFIG_SHELL is bash and it inherits a
+      # broken ls alias from the environment.  This has actually
+      # happened.  Such a system could not be considered "sane".
+      AC_MSG_ERROR([ls -t appears to fail.  Make sure there is not a broken
+alias in your environment])
+   fi
+
+   test "$[2]" = conftest.file
+   )
+then
+   # Ok.
+   :
+else
+   AC_MSG_ERROR([newly created file is older than distributed files!
+Check your system clock])
+fi
+AC_MSG_RESULT(yes)])
+
+# Copyright (C) 2001, 2003, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# AM_PROG_INSTALL_STRIP
+# ---------------------
+# One issue with vendor `install' (even GNU) is that you can't
+# specify the program used to strip binaries.  This is especially
+# annoying in cross-compiling environments, where the build's strip
+# is unlikely to handle the host's binaries.
+# Fortunately install-sh will honor a STRIPPROG variable, so we
+# always use install-sh in `make install-strip', and initialize
+# STRIPPROG with the value of the STRIP variable (set by the user).
+AC_DEFUN([AM_PROG_INSTALL_STRIP],
+[AC_REQUIRE([AM_PROG_INSTALL_SH])dnl
+# Installed binaries are usually stripped using `strip' when the user
+# run `make install-strip'.  However `strip' might not be the right
+# tool to use in cross-compilation environments, therefore Automake
+# will honor the `STRIP' environment variable to overrule this program.
+dnl Don't test for $cross_compiling = yes, because it might be `maybe'.
+if test "$cross_compiling" != no; then
+  AC_CHECK_TOOL([STRIP], [strip], :)
+fi
+INSTALL_STRIP_PROGRAM="\${SHELL} \$(install_sh) -c -s"
+AC_SUBST([INSTALL_STRIP_PROGRAM])])
+
+# Check how to create a tarball.                            -*- Autoconf -*-
+
+# Copyright (C) 2004, 2005  Free Software Foundation, Inc.
+#
+# This file is free software; the Free Software Foundation
+# gives unlimited permission to copy and/or distribute it,
+# with or without modifications, as long as this notice is preserved.
+
+# serial 2
+
+# _AM_PROG_TAR(FORMAT)
+# --------------------
+# Check how to create a tarball in format FORMAT.
+# FORMAT should be one of `v7', `ustar', or `pax'.
+#
+# Substitute a variable $(am__tar) that is a command
+# writing to stdout a FORMAT-tarball containing the directory
+# $tardir.
+#     tardir=directory && $(am__tar) > result.tar
+#
+# Substitute a variable $(am__untar) that extract such
+# a tarball read from stdin.
+#     $(am__untar) < result.tar
+AC_DEFUN([_AM_PROG_TAR],
+[# Always define AMTAR for backward compatibility.
+AM_MISSING_PROG([AMTAR], [tar])
+m4_if([$1], [v7],
+     [am__tar='${AMTAR} chof - "$$tardir"'; am__untar='${AMTAR} xf -'],
+     [m4_case([$1], [ustar],, [pax],,
+              [m4_fatal([Unknown tar format])])
+AC_MSG_CHECKING([how to create a $1 tar archive])
+# Loop over all known methods to create a tar archive until one works.
+_am_tools='gnutar m4_if([$1], [ustar], [plaintar]) pax cpio none'
+_am_tools=${am_cv_prog_tar_$1-$_am_tools}
+# Do not fold the above two line into one, because Tru64 sh and
+# Solaris sh will not grok spaces in the rhs of `-'.
+for _am_tool in $_am_tools
+do
+  case $_am_tool in
+  gnutar)
+    for _am_tar in tar gnutar gtar;
+    do
+      AM_RUN_LOG([$_am_tar --version]) && break
+    done
+    am__tar="$_am_tar --format=m4_if([$1], [pax], [posix], [$1]) -chf - "'"$$tardir"'
+    am__tar_="$_am_tar --format=m4_if([$1], [pax], [posix], [$1]) -chf - "'"$tardir"'
+    am__untar="$_am_tar -xf -"
+    ;;
+  plaintar)
+    # Must skip GNU tar: if it does not support --format= it doesn't create
+    # ustar tarball either.
+    (tar --version) >/dev/null 2>&1 && continue
+    am__tar='tar chf - "$$tardir"'
+    am__tar_='tar chf - "$tardir"'
+    am__untar='tar xf -'
+    ;;
+  pax)
+    am__tar='pax -L -x $1 -w "$$tardir"'
+    am__tar_='pax -L -x $1 -w "$tardir"'
+    am__untar='pax -r'
+    ;;
+  cpio)
+    am__tar='find "$$tardir" -print | cpio -o -H $1 -L'
+    am__tar_='find "$tardir" -print | cpio -o -H $1 -L'
+    am__untar='cpio -i -H $1 -d'
+    ;;
+  none)
+    am__tar=false
+    am__tar_=false
+    am__untar=false
+    ;;
+  esac
+
+  # If the value was cached, stop now.  We just wanted to have am__tar
+  # and am__untar set.
+  test -n "${am_cv_prog_tar_$1}" && break
+
+  # tar/untar a dummy directory, and stop if the command works
+  rm -rf conftest.dir
+  mkdir conftest.dir
+  echo GrepMe > conftest.dir/file
+  AM_RUN_LOG([tardir=conftest.dir && eval $am__tar_ >conftest.tar])
+  rm -rf conftest.dir
+  if test -s conftest.tar; then
+    AM_RUN_LOG([$am__untar <conftest.tar])
+    grep GrepMe conftest.dir/file >/dev/null 2>&1 && break
+  fi
+done
+rm -rf conftest.dir
+
+AC_CACHE_VAL([am_cv_prog_tar_$1], [am_cv_prog_tar_$1=$_am_tool])
+AC_MSG_RESULT([$am_cv_prog_tar_$1])])
+AC_SUBST([am__tar])
+AC_SUBST([am__untar])
+]) # _AM_PROG_TAR
+
diff --git a/libevent/autogen.sh b/libevent/autogen.sh
new file mode 100644
index 0000000..218dbf4
--- /dev/null
+++ b/libevent/autogen.sh
@@ -0,0 +1,8 @@
+#!/bin/sh
+
+aclocal && \
+	autoheader && \
+	autoconf && \
+	automake --foreign --force-missing --add-missing --copy
+
+rm -rf autom4te.cache
diff --git a/libevent/buffer.c b/libevent/buffer.c
new file mode 100644
index 0000000..e66080f
--- /dev/null
+++ b/libevent/buffer.c
@@ -0,0 +1,451 @@
+/*
+ * Copyright (c) 2002, 2003 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef WIN32
+#include <winsock2.h>
+#include <windows.h>
+#endif
+
+#ifdef HAVE_VASPRINTF
+/* If we have vasprintf, we need to define this before we include stdio.h. */
+#define _GNU_SOURCE
+#endif
+
+#include <sys/types.h>
+
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+
+#ifdef HAVE_SYS_IOCTL_H
+#include <sys/ioctl.h>
+#endif
+
+#include <assert.h>
+#include <errno.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#ifdef HAVE_STDARG_H
+#include <stdarg.h>
+#endif
+#ifdef HAVE_UNISTD_H
+#include <unistd.h>
+#endif
+
+#include "event.h"
+#include "config.h"
+#include "evutil.h"
+
+struct evbuffer *
+evbuffer_new(void)
+{
+	struct evbuffer *buffer;
+	
+	buffer = calloc(1, sizeof(struct evbuffer));
+
+	return (buffer);
+}
+
+void
+evbuffer_free(struct evbuffer *buffer)
+{
+	if (buffer->orig_buffer != NULL)
+		free(buffer->orig_buffer);
+	free(buffer);
+}
+
+/* 
+ * This is a destructive add.  The data from one buffer moves into
+ * the other buffer.
+ */
+
+#define SWAP(x,y) do { \
+	(x)->buffer = (y)->buffer; \
+	(x)->orig_buffer = (y)->orig_buffer; \
+	(x)->misalign = (y)->misalign; \
+	(x)->totallen = (y)->totallen; \
+	(x)->off = (y)->off; \
+} while (0)
+
+int
+evbuffer_add_buffer(struct evbuffer *outbuf, struct evbuffer *inbuf)
+{
+	int res;
+
+	/* Short cut for better performance */
+	if (outbuf->off == 0) {
+		struct evbuffer tmp;
+		size_t oldoff = inbuf->off;
+
+		/* Swap them directly */
+		SWAP(&tmp, outbuf);
+		SWAP(outbuf, inbuf);
+		SWAP(inbuf, &tmp);
+
+		/* 
+		 * Optimization comes with a price; we need to notify the
+		 * buffer if necessary of the changes. oldoff is the amount
+		 * of data that we transfered from inbuf to outbuf
+		 */
+		if (inbuf->off != oldoff && inbuf->cb != NULL)
+			(*inbuf->cb)(inbuf, oldoff, inbuf->off, inbuf->cbarg);
+		if (oldoff && outbuf->cb != NULL)
+			(*outbuf->cb)(outbuf, 0, oldoff, outbuf->cbarg);
+		
+		return (0);
+	}
+
+	res = evbuffer_add(outbuf, inbuf->buffer, inbuf->off);
+	if (res == 0) {
+		/* We drain the input buffer on success */
+		evbuffer_drain(inbuf, inbuf->off);
+	}
+
+	return (res);
+}
+
+int
+evbuffer_add_vprintf(struct evbuffer *buf, const char *fmt, va_list ap)
+{
+	char *buffer;
+	size_t space;
+	size_t oldoff = buf->off;
+	int sz;
+	va_list aq;
+
+	/* make sure that at least some space is available */
+	evbuffer_expand(buf, 64);
+	for (;;) {
+		size_t used = buf->misalign + buf->off;
+		buffer = (char *)buf->buffer + buf->off;
+		assert(buf->totallen >= used);
+		space = buf->totallen - used;
+
+#ifndef va_copy
+#define	va_copy(dst, src)	memcpy(&(dst), &(src), sizeof(va_list))
+#endif
+		va_copy(aq, ap);
+
+		sz = evutil_vsnprintf(buffer, space, fmt, aq);
+
+		va_end(aq);
+
+		if (sz < 0)
+			return (-1);
+		if (sz < space) {
+			buf->off += sz;
+			if (buf->cb != NULL)
+				(*buf->cb)(buf, oldoff, buf->off, buf->cbarg);
+			return (sz);
+		}
+		if (evbuffer_expand(buf, sz + 1) == -1)
+			return (-1);
+
+	}
+	/* NOTREACHED */
+}
+
+int
+evbuffer_add_printf(struct evbuffer *buf, const char *fmt, ...)
+{
+	int res = -1;
+	va_list ap;
+
+	va_start(ap, fmt);
+	res = evbuffer_add_vprintf(buf, fmt, ap);
+	va_end(ap);
+
+	return (res);
+}
+
+/* Reads data from an event buffer and drains the bytes read */
+
+int
+evbuffer_remove(struct evbuffer *buf, void *data, size_t datlen)
+{
+	size_t nread = datlen;
+	if (nread >= buf->off)
+		nread = buf->off;
+
+	memcpy(data, buf->buffer, nread);
+	evbuffer_drain(buf, nread);
+	
+	return (nread);
+}
+
+/*
+ * Reads a line terminated by either '\r\n', '\n\r' or '\r' or '\n'.
+ * The returned buffer needs to be freed by the called.
+ */
+
+char *
+evbuffer_readline(struct evbuffer *buffer)
+{
+	u_char *data = EVBUFFER_DATA(buffer);
+	size_t len = EVBUFFER_LENGTH(buffer);
+	char *line;
+	unsigned int i;
+
+	for (i = 0; i < len; i++) {
+		if (data[i] == '\r' || data[i] == '\n')
+			break;
+	}
+
+	if (i == len)
+		return (NULL);
+
+	if ((line = malloc(i + 1)) == NULL) {
+		fprintf(stderr, "%s: out of memory\n", __func__);
+		evbuffer_drain(buffer, i);
+		return (NULL);
+	}
+
+	memcpy(line, data, i);
+	line[i] = '\0';
+
+	/*
+	 * Some protocols terminate a line with '\r\n', so check for
+	 * that, too.
+	 */
+	if ( i < len - 1 ) {
+		char fch = data[i], sch = data[i+1];
+
+		/* Drain one more character if needed */
+		if ( (sch == '\r' || sch == '\n') && sch != fch )
+			i += 1;
+	}
+
+	evbuffer_drain(buffer, i + 1);
+
+	return (line);
+}
+
+/* Adds data to an event buffer */
+
+static void
+evbuffer_align(struct evbuffer *buf)
+{
+	memmove(buf->orig_buffer, buf->buffer, buf->off);
+	buf->buffer = buf->orig_buffer;
+	buf->misalign = 0;
+}
+
+/* Expands the available space in the event buffer to at least datlen */
+
+int
+evbuffer_expand(struct evbuffer *buf, size_t datlen)
+{
+	size_t need = buf->misalign + buf->off + datlen;
+
+	/* If we can fit all the data, then we don't have to do anything */
+	if (buf->totallen >= need)
+		return (0);
+
+	/*
+	 * If the misalignment fulfills our data needs, we just force an
+	 * alignment to happen.  Afterwards, we have enough space.
+	 */
+	if (buf->misalign >= datlen) {
+		evbuffer_align(buf);
+	} else {
+		void *newbuf;
+		size_t length = buf->totallen;
+
+		if (length < 256)
+			length = 256;
+		while (length < need)
+			length <<= 1;
+
+		if (buf->orig_buffer != buf->buffer)
+			evbuffer_align(buf);
+		if ((newbuf = realloc(buf->buffer, length)) == NULL)
+			return (-1);
+
+		buf->orig_buffer = buf->buffer = newbuf;
+		buf->totallen = length;
+	}
+
+	return (0);
+}
+
+int
+evbuffer_add(struct evbuffer *buf, const void *data, size_t datlen)
+{
+	size_t need = buf->misalign + buf->off + datlen;
+	size_t oldoff = buf->off;
+
+	if (buf->totallen < need) {
+		if (evbuffer_expand(buf, datlen) == -1)
+			return (-1);
+	}
+
+	memcpy(buf->buffer + buf->off, data, datlen);
+	buf->off += datlen;
+
+	if (datlen && buf->cb != NULL)
+		(*buf->cb)(buf, oldoff, buf->off, buf->cbarg);
+
+	return (0);
+}
+
+void
+evbuffer_drain(struct evbuffer *buf, size_t len)
+{
+	size_t oldoff = buf->off;
+
+	if (len >= buf->off) {
+		buf->off = 0;
+		buf->buffer = buf->orig_buffer;
+		buf->misalign = 0;
+		goto done;
+	}
+
+	buf->buffer += len;
+	buf->misalign += len;
+
+	buf->off -= len;
+
+ done:
+	/* Tell someone about changes in this buffer */
+	if (buf->off != oldoff && buf->cb != NULL)
+		(*buf->cb)(buf, oldoff, buf->off, buf->cbarg);
+
+}
+
+/*
+ * Reads data from a file descriptor into a buffer.
+ */
+
+#define EVBUFFER_MAX_READ	4096
+
+int
+evbuffer_read(struct evbuffer *buf, int fd, int howmuch)
+{
+	u_char *p;
+	size_t oldoff = buf->off;
+	int n = EVBUFFER_MAX_READ;
+
+#if defined(FIONREAD)
+#ifdef WIN32
+	long lng = n;
+	if (ioctlsocket(fd, FIONREAD, &lng) == -1 || (n=lng) == 0) {
+#else
+	if (ioctl(fd, FIONREAD, &n) == -1 || n == 0) {
+#endif
+		n = EVBUFFER_MAX_READ;
+	} else if (n > EVBUFFER_MAX_READ && n > howmuch) {
+		/*
+		 * It's possible that a lot of data is available for
+		 * reading.  We do not want to exhaust resources
+		 * before the reader has a chance to do something
+		 * about it.  If the reader does not tell us how much
+		 * data we should read, we artifically limit it.
+		 */
+		if (n > buf->totallen << 2)
+			n = buf->totallen << 2;
+		if (n < EVBUFFER_MAX_READ)
+			n = EVBUFFER_MAX_READ;
+	}
+#endif	
+	if (howmuch < 0 || howmuch > n)
+		howmuch = n;
+
+	/* If we don't have FIONREAD, we might waste some space here */
+	if (evbuffer_expand(buf, howmuch) == -1)
+		return (-1);
+
+	/* We can append new data at this point */
+	p = buf->buffer + buf->off;
+
+#ifndef WIN32
+	n = read(fd, p, howmuch);
+#else
+	n = recv(fd, p, howmuch, 0);
+#endif
+	if (n == -1)
+		return (-1);
+	if (n == 0)
+		return (0);
+
+	buf->off += n;
+
+	/* Tell someone about changes in this buffer */
+	if (buf->off != oldoff && buf->cb != NULL)
+		(*buf->cb)(buf, oldoff, buf->off, buf->cbarg);
+
+	return (n);
+}
+
+int
+evbuffer_write(struct evbuffer *buffer, int fd)
+{
+	int n;
+
+#ifndef WIN32
+	n = write(fd, buffer->buffer, buffer->off);
+#else
+	n = send(fd, buffer->buffer, buffer->off, 0);
+#endif
+	if (n == -1)
+		return (-1);
+	if (n == 0)
+		return (0);
+	evbuffer_drain(buffer, n);
+
+	return (n);
+}
+
+u_char *
+evbuffer_find(struct evbuffer *buffer, const u_char *what, size_t len)
+{
+	u_char *search = buffer->buffer, *end = search + buffer->off;
+	u_char *p;
+
+	while (search < end &&
+	    (p = memchr(search, *what, end - search)) != NULL) {
+		if (p + len > end)
+			break;
+		if (memcmp(p, what, len) == 0)
+			return (p);
+		search = p + 1;
+	}
+
+	return (NULL);
+}
+
+void evbuffer_setcb(struct evbuffer *buffer,
+    void (*cb)(struct evbuffer *, size_t, size_t, void *),
+    void *cbarg)
+{
+	buffer->cb = cb;
+	buffer->cbarg = cbarg;
+}
diff --git a/libevent/compat/sys/_time.h b/libevent/compat/sys/_time.h
new file mode 100644
index 0000000..8cabb0d
--- /dev/null
+++ b/libevent/compat/sys/_time.h
@@ -0,0 +1,163 @@
+/*	$OpenBSD: time.h,v 1.11 2000/10/10 13:36:48 itojun Exp $	*/
+/*	$NetBSD: time.h,v 1.18 1996/04/23 10:29:33 mycroft Exp $	*/
+
+/*
+ * Copyright (c) 1982, 1986, 1993
+ *	The Regents of the University of California.  All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. Neither the name of the University nor the names of its contributors
+ *    may be used to endorse or promote products derived from this software
+ *    without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
+ * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
+ * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
+ * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
+ * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
+ * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
+ * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
+ * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
+ * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
+ * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
+ * SUCH DAMAGE.
+ *
+ *	@(#)time.h	8.2 (Berkeley) 7/10/94
+ */
+
+#ifndef _SYS_TIME_H_
+#define _SYS_TIME_H_
+
+#include <sys/types.h>
+
+/*
+ * Structure returned by gettimeofday(2) system call,
+ * and used in other calls.
+ */
+struct timeval {
+	long	tv_sec;		/* seconds */
+	long	tv_usec;	/* and microseconds */
+};
+
+/*
+ * Structure defined by POSIX.1b to be like a timeval.
+ */
+struct timespec {
+	time_t	tv_sec;		/* seconds */
+	long	tv_nsec;	/* and nanoseconds */
+};
+
+#define	TIMEVAL_TO_TIMESPEC(tv, ts) {					\
+	(ts)->tv_sec = (tv)->tv_sec;					\
+	(ts)->tv_nsec = (tv)->tv_usec * 1000;				\
+}
+#define	TIMESPEC_TO_TIMEVAL(tv, ts) {					\
+	(tv)->tv_sec = (ts)->tv_sec;					\
+	(tv)->tv_usec = (ts)->tv_nsec / 1000;				\
+}
+
+struct timezone {
+	int	tz_minuteswest;	/* minutes west of Greenwich */
+	int	tz_dsttime;	/* type of dst correction */
+};
+#define	DST_NONE	0	/* not on dst */
+#define	DST_USA		1	/* USA style dst */
+#define	DST_AUST	2	/* Australian style dst */
+#define	DST_WET		3	/* Western European dst */
+#define	DST_MET		4	/* Middle European dst */
+#define	DST_EET		5	/* Eastern European dst */
+#define	DST_CAN		6	/* Canada */
+
+/* Operations on timevals. */
+#define	timerclear(tvp)		(tvp)->tv_sec = (tvp)->tv_usec = 0
+#define	timerisset(tvp)		((tvp)->tv_sec || (tvp)->tv_usec)
+#define	timercmp(tvp, uvp, cmp)						\
+	(((tvp)->tv_sec == (uvp)->tv_sec) ?				\
+	    ((tvp)->tv_usec cmp (uvp)->tv_usec) :			\
+	    ((tvp)->tv_sec cmp (uvp)->tv_sec))
+#define	timeradd(tvp, uvp, vvp)						\
+	do {								\
+		(vvp)->tv_sec = (tvp)->tv_sec + (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec + (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec >= 1000000) {			\
+			(vvp)->tv_sec++;				\
+			(vvp)->tv_usec -= 1000000;			\
+		}							\
+	} while (0)
+#define	timersub(tvp, uvp, vvp)						\
+	do {								\
+		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec < 0) {				\
+			(vvp)->tv_sec--;				\
+			(vvp)->tv_usec += 1000000;			\
+		}							\
+	} while (0)
+
+/* Operations on timespecs. */
+#define	timespecclear(tsp)		(tsp)->tv_sec = (tsp)->tv_nsec = 0
+#define	timespecisset(tsp)		((tsp)->tv_sec || (tsp)->tv_nsec)
+#define	timespeccmp(tsp, usp, cmp)					\
+	(((tsp)->tv_sec == (usp)->tv_sec) ?				\
+	    ((tsp)->tv_nsec cmp (usp)->tv_nsec) :			\
+	    ((tsp)->tv_sec cmp (usp)->tv_sec))
+#define	timespecadd(tsp, usp, vsp)					\
+	do {								\
+		(vsp)->tv_sec = (tsp)->tv_sec + (usp)->tv_sec;		\
+		(vsp)->tv_nsec = (tsp)->tv_nsec + (usp)->tv_nsec;	\
+		if ((vsp)->tv_nsec >= 1000000000L) {			\
+			(vsp)->tv_sec++;				\
+			(vsp)->tv_nsec -= 1000000000L;			\
+		}							\
+	} while (0)
+#define	timespecsub(tsp, usp, vsp)					\
+	do {								\
+		(vsp)->tv_sec = (tsp)->tv_sec - (usp)->tv_sec;		\
+		(vsp)->tv_nsec = (tsp)->tv_nsec - (usp)->tv_nsec;	\
+		if ((vsp)->tv_nsec < 0) {				\
+			(vsp)->tv_sec--;				\
+			(vsp)->tv_nsec += 1000000000L;			\
+		}							\
+	} while (0)
+
+/*
+ * Names of the interval timers, and structure
+ * defining a timer setting.
+ */
+#define	ITIMER_REAL	0
+#define	ITIMER_VIRTUAL	1
+#define	ITIMER_PROF	2
+
+struct	itimerval {
+	struct	timeval it_interval;	/* timer interval */
+	struct	timeval it_value;	/* current value */
+};
+
+/*
+ * Getkerninfo clock information structure
+ */
+struct clockinfo {
+	int	hz;		/* clock frequency */
+	int	tick;		/* micro-seconds per hz tick */
+	int	tickadj;	/* clock skew rate for adjtime() */
+	int	stathz;		/* statistics clock frequency */
+	int	profhz;		/* profiling clock frequency */
+};
+
+#define CLOCK_REALTIME	0
+#define CLOCK_VIRTUAL	1
+#define CLOCK_PROF	2
+
+#define TIMER_RELTIME	0x0	/* relative timer */
+#define TIMER_ABSTIME	0x1	/* absolute timer */
+
+/* --- stuff got cut here - niels --- */
+
+#endif /* !_SYS_TIME_H_ */
diff --git a/libevent/compat/sys/queue.h b/libevent/compat/sys/queue.h
new file mode 100644
index 0000000..c0956dd
--- /dev/null
+++ b/libevent/compat/sys/queue.h
@@ -0,0 +1,488 @@
+/*	$OpenBSD: queue.h,v 1.16 2000/09/07 19:47:59 art Exp $	*/
+/*	$NetBSD: queue.h,v 1.11 1996/05/16 05:17:14 mycroft Exp $	*/
+
+/*
+ * Copyright (c) 1991, 1993
+ *	The Regents of the University of California.  All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. Neither the name of the University nor the names of its contributors
+ *    may be used to endorse or promote products derived from this software
+ *    without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
+ * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
+ * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
+ * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
+ * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
+ * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
+ * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
+ * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
+ * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
+ * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
+ * SUCH DAMAGE.
+ *
+ *	@(#)queue.h	8.5 (Berkeley) 8/20/94
+ */
+
+#ifndef	_SYS_QUEUE_H_
+#define	_SYS_QUEUE_H_
+
+/*
+ * This file defines five types of data structures: singly-linked lists, 
+ * lists, simple queues, tail queues, and circular queues.
+ *
+ *
+ * A singly-linked list is headed by a single forward pointer. The elements
+ * are singly linked for minimum space and pointer manipulation overhead at
+ * the expense of O(n) removal for arbitrary elements. New elements can be
+ * added to the list after an existing element or at the head of the list.
+ * Elements being removed from the head of the list should use the explicit
+ * macro for this purpose for optimum efficiency. A singly-linked list may
+ * only be traversed in the forward direction.  Singly-linked lists are ideal
+ * for applications with large datasets and few or no removals or for
+ * implementing a LIFO queue.
+ *
+ * A list is headed by a single forward pointer (or an array of forward
+ * pointers for a hash table header). The elements are doubly linked
+ * so that an arbitrary element can be removed without a need to
+ * traverse the list. New elements can be added to the list before
+ * or after an existing element or at the head of the list. A list
+ * may only be traversed in the forward direction.
+ *
+ * A simple queue is headed by a pair of pointers, one the head of the
+ * list and the other to the tail of the list. The elements are singly
+ * linked to save space, so elements can only be removed from the
+ * head of the list. New elements can be added to the list before or after
+ * an existing element, at the head of the list, or at the end of the
+ * list. A simple queue may only be traversed in the forward direction.
+ *
+ * A tail queue is headed by a pair of pointers, one to the head of the
+ * list and the other to the tail of the list. The elements are doubly
+ * linked so that an arbitrary element can be removed without a need to
+ * traverse the list. New elements can be added to the list before or
+ * after an existing element, at the head of the list, or at the end of
+ * the list. A tail queue may be traversed in either direction.
+ *
+ * A circle queue is headed by a pair of pointers, one to the head of the
+ * list and the other to the tail of the list. The elements are doubly
+ * linked so that an arbitrary element can be removed without a need to
+ * traverse the list. New elements can be added to the list before or after
+ * an existing element, at the head of the list, or at the end of the list.
+ * A circle queue may be traversed in either direction, but has a more
+ * complex end of list detection.
+ *
+ * For details on the use of these macros, see the queue(3) manual page.
+ */
+
+/*
+ * Singly-linked List definitions.
+ */
+#define SLIST_HEAD(name, type)						\
+struct name {								\
+	struct type *slh_first;	/* first element */			\
+}
+ 
+#define	SLIST_HEAD_INITIALIZER(head)					\
+	{ NULL }
+
+#ifndef WIN32
+#define SLIST_ENTRY(type)						\
+struct {								\
+	struct type *sle_next;	/* next element */			\
+}
+#endif
+
+/*
+ * Singly-linked List access methods.
+ */
+#define	SLIST_FIRST(head)	((head)->slh_first)
+#define	SLIST_END(head)		NULL
+#define	SLIST_EMPTY(head)	(SLIST_FIRST(head) == SLIST_END(head))
+#define	SLIST_NEXT(elm, field)	((elm)->field.sle_next)
+
+#define	SLIST_FOREACH(var, head, field)					\
+	for((var) = SLIST_FIRST(head);					\
+	    (var) != SLIST_END(head);					\
+	    (var) = SLIST_NEXT(var, field))
+
+/*
+ * Singly-linked List functions.
+ */
+#define	SLIST_INIT(head) {						\
+	SLIST_FIRST(head) = SLIST_END(head);				\
+}
+
+#define	SLIST_INSERT_AFTER(slistelm, elm, field) do {			\
+	(elm)->field.sle_next = (slistelm)->field.sle_next;		\
+	(slistelm)->field.sle_next = (elm);				\
+} while (0)
+
+#define	SLIST_INSERT_HEAD(head, elm, field) do {			\
+	(elm)->field.sle_next = (head)->slh_first;			\
+	(head)->slh_first = (elm);					\
+} while (0)
+
+#define	SLIST_REMOVE_HEAD(head, field) do {				\
+	(head)->slh_first = (head)->slh_first->field.sle_next;		\
+} while (0)
+
+/*
+ * List definitions.
+ */
+#define LIST_HEAD(name, type)						\
+struct name {								\
+	struct type *lh_first;	/* first element */			\
+}
+
+#define LIST_HEAD_INITIALIZER(head)					\
+	{ NULL }
+
+#define LIST_ENTRY(type)						\
+struct {								\
+	struct type *le_next;	/* next element */			\
+	struct type **le_prev;	/* address of previous next element */	\
+}
+
+/*
+ * List access methods
+ */
+#define	LIST_FIRST(head)		((head)->lh_first)
+#define	LIST_END(head)			NULL
+#define	LIST_EMPTY(head)		(LIST_FIRST(head) == LIST_END(head))
+#define	LIST_NEXT(elm, field)		((elm)->field.le_next)
+
+#define LIST_FOREACH(var, head, field)					\
+	for((var) = LIST_FIRST(head);					\
+	    (var)!= LIST_END(head);					\
+	    (var) = LIST_NEXT(var, field))
+
+/*
+ * List functions.
+ */
+#define	LIST_INIT(head) do {						\
+	LIST_FIRST(head) = LIST_END(head);				\
+} while (0)
+
+#define LIST_INSERT_AFTER(listelm, elm, field) do {			\
+	if (((elm)->field.le_next = (listelm)->field.le_next) != NULL)	\
+		(listelm)->field.le_next->field.le_prev =		\
+		    &(elm)->field.le_next;				\
+	(listelm)->field.le_next = (elm);				\
+	(elm)->field.le_prev = &(listelm)->field.le_next;		\
+} while (0)
+
+#define	LIST_INSERT_BEFORE(listelm, elm, field) do {			\
+	(elm)->field.le_prev = (listelm)->field.le_prev;		\
+	(elm)->field.le_next = (listelm);				\
+	*(listelm)->field.le_prev = (elm);				\
+	(listelm)->field.le_prev = &(elm)->field.le_next;		\
+} while (0)
+
+#define LIST_INSERT_HEAD(head, elm, field) do {				\
+	if (((elm)->field.le_next = (head)->lh_first) != NULL)		\
+		(head)->lh_first->field.le_prev = &(elm)->field.le_next;\
+	(head)->lh_first = (elm);					\
+	(elm)->field.le_prev = &(head)->lh_first;			\
+} while (0)
+
+#define LIST_REMOVE(elm, field) do {					\
+	if ((elm)->field.le_next != NULL)				\
+		(elm)->field.le_next->field.le_prev =			\
+		    (elm)->field.le_prev;				\
+	*(elm)->field.le_prev = (elm)->field.le_next;			\
+} while (0)
+
+#define LIST_REPLACE(elm, elm2, field) do {				\
+	if (((elm2)->field.le_next = (elm)->field.le_next) != NULL)	\
+		(elm2)->field.le_next->field.le_prev =			\
+		    &(elm2)->field.le_next;				\
+	(elm2)->field.le_prev = (elm)->field.le_prev;			\
+	*(elm2)->field.le_prev = (elm2);				\
+} while (0)
+
+/*
+ * Simple queue definitions.
+ */
+#define SIMPLEQ_HEAD(name, type)					\
+struct name {								\
+	struct type *sqh_first;	/* first element */			\
+	struct type **sqh_last;	/* addr of last next element */		\
+}
+
+#define SIMPLEQ_HEAD_INITIALIZER(head)					\
+	{ NULL, &(head).sqh_first }
+
+#define SIMPLEQ_ENTRY(type)						\
+struct {								\
+	struct type *sqe_next;	/* next element */			\
+}
+
+/*
+ * Simple queue access methods.
+ */
+#define	SIMPLEQ_FIRST(head)	    ((head)->sqh_first)
+#define	SIMPLEQ_END(head)	    NULL
+#define	SIMPLEQ_EMPTY(head)	    (SIMPLEQ_FIRST(head) == SIMPLEQ_END(head))
+#define	SIMPLEQ_NEXT(elm, field)    ((elm)->field.sqe_next)
+
+#define SIMPLEQ_FOREACH(var, head, field)				\
+	for((var) = SIMPLEQ_FIRST(head);				\
+	    (var) != SIMPLEQ_END(head);					\
+	    (var) = SIMPLEQ_NEXT(var, field))
+
+/*
+ * Simple queue functions.
+ */
+#define	SIMPLEQ_INIT(head) do {						\
+	(head)->sqh_first = NULL;					\
+	(head)->sqh_last = &(head)->sqh_first;				\
+} while (0)
+
+#define SIMPLEQ_INSERT_HEAD(head, elm, field) do {			\
+	if (((elm)->field.sqe_next = (head)->sqh_first) == NULL)	\
+		(head)->sqh_last = &(elm)->field.sqe_next;		\
+	(head)->sqh_first = (elm);					\
+} while (0)
+
+#define SIMPLEQ_INSERT_TAIL(head, elm, field) do {			\
+	(elm)->field.sqe_next = NULL;					\
+	*(head)->sqh_last = (elm);					\
+	(head)->sqh_last = &(elm)->field.sqe_next;			\
+} while (0)
+
+#define SIMPLEQ_INSERT_AFTER(head, listelm, elm, field) do {		\
+	if (((elm)->field.sqe_next = (listelm)->field.sqe_next) == NULL)\
+		(head)->sqh_last = &(elm)->field.sqe_next;		\
+	(listelm)->field.sqe_next = (elm);				\
+} while (0)
+
+#define SIMPLEQ_REMOVE_HEAD(head, elm, field) do {			\
+	if (((head)->sqh_first = (elm)->field.sqe_next) == NULL)	\
+		(head)->sqh_last = &(head)->sqh_first;			\
+} while (0)
+
+/*
+ * Tail queue definitions.
+ */
+#define TAILQ_HEAD(name, type)						\
+struct name {								\
+	struct type *tqh_first;	/* first element */			\
+	struct type **tqh_last;	/* addr of last next element */		\
+}
+
+#define TAILQ_HEAD_INITIALIZER(head)					\
+	{ NULL, &(head).tqh_first }
+
+#define TAILQ_ENTRY(type)						\
+struct {								\
+	struct type *tqe_next;	/* next element */			\
+	struct type **tqe_prev;	/* address of previous next element */	\
+}
+
+/* 
+ * tail queue access methods 
+ */
+#define	TAILQ_FIRST(head)		((head)->tqh_first)
+#define	TAILQ_END(head)			NULL
+#define	TAILQ_NEXT(elm, field)		((elm)->field.tqe_next)
+#define TAILQ_LAST(head, headname)					\
+	(*(((struct headname *)((head)->tqh_last))->tqh_last))
+/* XXX */
+#define TAILQ_PREV(elm, headname, field)				\
+	(*(((struct headname *)((elm)->field.tqe_prev))->tqh_last))
+#define	TAILQ_EMPTY(head)						\
+	(TAILQ_FIRST(head) == TAILQ_END(head))
+
+#define TAILQ_FOREACH(var, head, field)					\
+	for((var) = TAILQ_FIRST(head);					\
+	    (var) != TAILQ_END(head);					\
+	    (var) = TAILQ_NEXT(var, field))
+
+#define TAILQ_FOREACH_REVERSE(var, head, field, headname)		\
+	for((var) = TAILQ_LAST(head, headname);				\
+	    (var) != TAILQ_END(head);					\
+	    (var) = TAILQ_PREV(var, headname, field))
+
+/*
+ * Tail queue functions.
+ */
+#define	TAILQ_INIT(head) do {						\
+	(head)->tqh_first = NULL;					\
+	(head)->tqh_last = &(head)->tqh_first;				\
+} while (0)
+
+#define TAILQ_INSERT_HEAD(head, elm, field) do {			\
+	if (((elm)->field.tqe_next = (head)->tqh_first) != NULL)	\
+		(head)->tqh_first->field.tqe_prev =			\
+		    &(elm)->field.tqe_next;				\
+	else								\
+		(head)->tqh_last = &(elm)->field.tqe_next;		\
+	(head)->tqh_first = (elm);					\
+	(elm)->field.tqe_prev = &(head)->tqh_first;			\
+} while (0)
+
+#define TAILQ_INSERT_TAIL(head, elm, field) do {			\
+	(elm)->field.tqe_next = NULL;					\
+	(elm)->field.tqe_prev = (head)->tqh_last;			\
+	*(head)->tqh_last = (elm);					\
+	(head)->tqh_last = &(elm)->field.tqe_next;			\
+} while (0)
+
+#define TAILQ_INSERT_AFTER(head, listelm, elm, field) do {		\
+	if (((elm)->field.tqe_next = (listelm)->field.tqe_next) != NULL)\
+		(elm)->field.tqe_next->field.tqe_prev =			\
+		    &(elm)->field.tqe_next;				\
+	else								\
+		(head)->tqh_last = &(elm)->field.tqe_next;		\
+	(listelm)->field.tqe_next = (elm);				\
+	(elm)->field.tqe_prev = &(listelm)->field.tqe_next;		\
+} while (0)
+
+#define	TAILQ_INSERT_BEFORE(listelm, elm, field) do {			\
+	(elm)->field.tqe_prev = (listelm)->field.tqe_prev;		\
+	(elm)->field.tqe_next = (listelm);				\
+	*(listelm)->field.tqe_prev = (elm);				\
+	(listelm)->field.tqe_prev = &(elm)->field.tqe_next;		\
+} while (0)
+
+#define TAILQ_REMOVE(head, elm, field) do {				\
+	if (((elm)->field.tqe_next) != NULL)				\
+		(elm)->field.tqe_next->field.tqe_prev =			\
+		    (elm)->field.tqe_prev;				\
+	else								\
+		(head)->tqh_last = (elm)->field.tqe_prev;		\
+	*(elm)->field.tqe_prev = (elm)->field.tqe_next;			\
+} while (0)
+
+#define TAILQ_REPLACE(head, elm, elm2, field) do {			\
+	if (((elm2)->field.tqe_next = (elm)->field.tqe_next) != NULL)	\
+		(elm2)->field.tqe_next->field.tqe_prev =		\
+		    &(elm2)->field.tqe_next;				\
+	else								\
+		(head)->tqh_last = &(elm2)->field.tqe_next;		\
+	(elm2)->field.tqe_prev = (elm)->field.tqe_prev;			\
+	*(elm2)->field.tqe_prev = (elm2);				\
+} while (0)
+
+/*
+ * Circular queue definitions.
+ */
+#define CIRCLEQ_HEAD(name, type)					\
+struct name {								\
+	struct type *cqh_first;		/* first element */		\
+	struct type *cqh_last;		/* last element */		\
+}
+
+#define CIRCLEQ_HEAD_INITIALIZER(head)					\
+	{ CIRCLEQ_END(&head), CIRCLEQ_END(&head) }
+
+#define CIRCLEQ_ENTRY(type)						\
+struct {								\
+	struct type *cqe_next;		/* next element */		\
+	struct type *cqe_prev;		/* previous element */		\
+}
+
+/*
+ * Circular queue access methods 
+ */
+#define	CIRCLEQ_FIRST(head)		((head)->cqh_first)
+#define	CIRCLEQ_LAST(head)		((head)->cqh_last)
+#define	CIRCLEQ_END(head)		((void *)(head))
+#define	CIRCLEQ_NEXT(elm, field)	((elm)->field.cqe_next)
+#define	CIRCLEQ_PREV(elm, field)	((elm)->field.cqe_prev)
+#define	CIRCLEQ_EMPTY(head)						\
+	(CIRCLEQ_FIRST(head) == CIRCLEQ_END(head))
+
+#define CIRCLEQ_FOREACH(var, head, field)				\
+	for((var) = CIRCLEQ_FIRST(head);				\
+	    (var) != CIRCLEQ_END(head);					\
+	    (var) = CIRCLEQ_NEXT(var, field))
+
+#define CIRCLEQ_FOREACH_REVERSE(var, head, field)			\
+	for((var) = CIRCLEQ_LAST(head);					\
+	    (var) != CIRCLEQ_END(head);					\
+	    (var) = CIRCLEQ_PREV(var, field))
+
+/*
+ * Circular queue functions.
+ */
+#define	CIRCLEQ_INIT(head) do {						\
+	(head)->cqh_first = CIRCLEQ_END(head);				\
+	(head)->cqh_last = CIRCLEQ_END(head);				\
+} while (0)
+
+#define CIRCLEQ_INSERT_AFTER(head, listelm, elm, field) do {		\
+	(elm)->field.cqe_next = (listelm)->field.cqe_next;		\
+	(elm)->field.cqe_prev = (listelm);				\
+	if ((listelm)->field.cqe_next == CIRCLEQ_END(head))		\
+		(head)->cqh_last = (elm);				\
+	else								\
+		(listelm)->field.cqe_next->field.cqe_prev = (elm);	\
+	(listelm)->field.cqe_next = (elm);				\
+} while (0)
+
+#define CIRCLEQ_INSERT_BEFORE(head, listelm, elm, field) do {		\
+	(elm)->field.cqe_next = (listelm);				\
+	(elm)->field.cqe_prev = (listelm)->field.cqe_prev;		\
+	if ((listelm)->field.cqe_prev == CIRCLEQ_END(head))		\
+		(head)->cqh_first = (elm);				\
+	else								\
+		(listelm)->field.cqe_prev->field.cqe_next = (elm);	\
+	(listelm)->field.cqe_prev = (elm);				\
+} while (0)
+
+#define CIRCLEQ_INSERT_HEAD(head, elm, field) do {			\
+	(elm)->field.cqe_next = (head)->cqh_first;			\
+	(elm)->field.cqe_prev = CIRCLEQ_END(head);			\
+	if ((head)->cqh_last == CIRCLEQ_END(head))			\
+		(head)->cqh_last = (elm);				\
+	else								\
+		(head)->cqh_first->field.cqe_prev = (elm);		\
+	(head)->cqh_first = (elm);					\
+} while (0)
+
+#define CIRCLEQ_INSERT_TAIL(head, elm, field) do {			\
+	(elm)->field.cqe_next = CIRCLEQ_END(head);			\
+	(elm)->field.cqe_prev = (head)->cqh_last;			\
+	if ((head)->cqh_first == CIRCLEQ_END(head))			\
+		(head)->cqh_first = (elm);				\
+	else								\
+		(head)->cqh_last->field.cqe_next = (elm);		\
+	(head)->cqh_last = (elm);					\
+} while (0)
+
+#define	CIRCLEQ_REMOVE(head, elm, field) do {				\
+	if ((elm)->field.cqe_next == CIRCLEQ_END(head))			\
+		(head)->cqh_last = (elm)->field.cqe_prev;		\
+	else								\
+		(elm)->field.cqe_next->field.cqe_prev =			\
+		    (elm)->field.cqe_prev;				\
+	if ((elm)->field.cqe_prev == CIRCLEQ_END(head))			\
+		(head)->cqh_first = (elm)->field.cqe_next;		\
+	else								\
+		(elm)->field.cqe_prev->field.cqe_next =			\
+		    (elm)->field.cqe_next;				\
+} while (0)
+
+#define CIRCLEQ_REPLACE(head, elm, elm2, field) do {			\
+	if (((elm2)->field.cqe_next = (elm)->field.cqe_next) ==		\
+	    CIRCLEQ_END(head))						\
+		(head).cqh_last = (elm2);				\
+	else								\
+		(elm2)->field.cqe_next->field.cqe_prev = (elm2);	\
+	if (((elm2)->field.cqe_prev = (elm)->field.cqe_prev) ==		\
+	    CIRCLEQ_END(head))						\
+		(head).cqh_first = (elm2);				\
+	else								\
+		(elm2)->field.cqe_prev->field.cqe_next = (elm2);	\
+} while (0)
+
+#endif	/* !_SYS_QUEUE_H_ */
diff --git a/libevent/config.h.in b/libevent/config.h.in
new file mode 100644
index 0000000..d151f87
--- /dev/null
+++ b/libevent/config.h.in
@@ -0,0 +1,250 @@
+/* config.h.in.  Generated from configure.in by autoheader.  */
+
+/* Define if clock_gettime is available in libc */
+#undef DNS_USE_CPU_CLOCK_FOR_ID
+
+/* Define is no secure id variant is available */
+#undef DNS_USE_GETTIMEOFDAY_FOR_ID
+
+/* Define to 1 if you have the `clock_gettime' function. */
+#undef HAVE_CLOCK_GETTIME
+
+/* Define if /dev/poll is available */
+#undef HAVE_DEVPOLL
+
+/* Define if your system supports the epoll system calls */
+#undef HAVE_EPOLL
+
+/* Define to 1 if you have the `epoll_ctl' function. */
+#undef HAVE_EPOLL_CTL
+
+/* Define if your system supports event ports */
+#undef HAVE_EVENT_PORTS
+
+/* Define to 1 if you have the `fcntl' function. */
+#undef HAVE_FCNTL
+
+/* Define to 1 if you have the <fcntl.h> header file. */
+#undef HAVE_FCNTL_H
+
+/* Define to 1 if you have the `getaddrinfo' function. */
+#undef HAVE_GETADDRINFO
+
+/* Define to 1 if you have the `getnameinfo' function. */
+#undef HAVE_GETNAMEINFO
+
+/* Define to 1 if you have the `gettimeofday' function. */
+#undef HAVE_GETTIMEOFDAY
+
+/* Define to 1 if you have the `inet_ntop' function. */
+#undef HAVE_INET_NTOP
+
+/* Define to 1 if you have the <inttypes.h> header file. */
+#undef HAVE_INTTYPES_H
+
+/* Define to 1 if you have the `kqueue' function. */
+#undef HAVE_KQUEUE
+
+/* Define to 1 if you have the `nsl' library (-lnsl). */
+#undef HAVE_LIBNSL
+
+/* Define to 1 if you have the `resolv' library (-lresolv). */
+#undef HAVE_LIBRESOLV
+
+/* Define to 1 if you have the `rt' library (-lrt). */
+#undef HAVE_LIBRT
+
+/* Define to 1 if you have the `socket' library (-lsocket). */
+#undef HAVE_LIBSOCKET
+
+/* Define to 1 if you have the <memory.h> header file. */
+#undef HAVE_MEMORY_H
+
+/* Define to 1 if you have the <netinet/in6.h> header file. */
+#undef HAVE_NETINET_IN6_H
+
+/* Define to 1 if you have the `poll' function. */
+#undef HAVE_POLL
+
+/* Define to 1 if you have the <poll.h> header file. */
+#undef HAVE_POLL_H
+
+/* Define to 1 if you have the `port_create' function. */
+#undef HAVE_PORT_CREATE
+
+/* Define to 1 if you have the <port.h> header file. */
+#undef HAVE_PORT_H
+
+/* Define to 1 if you have the `select' function. */
+#undef HAVE_SELECT
+
+/* Define if F_SETFD is defined in <fcntl.h> */
+#undef HAVE_SETFD
+
+/* Define to 1 if you have the `sigaction' function. */
+#undef HAVE_SIGACTION
+
+/* Define to 1 if you have the `signal' function. */
+#undef HAVE_SIGNAL
+
+/* Define to 1 if you have the <signal.h> header file. */
+#undef HAVE_SIGNAL_H
+
+/* Define to 1 if you have the <stdarg.h> header file. */
+#undef HAVE_STDARG_H
+
+/* Define to 1 if you have the <stdint.h> header file. */
+#undef HAVE_STDINT_H
+
+/* Define to 1 if you have the <stdlib.h> header file. */
+#undef HAVE_STDLIB_H
+
+/* Define to 1 if you have the <strings.h> header file. */
+#undef HAVE_STRINGS_H
+
+/* Define to 1 if you have the <string.h> header file. */
+#undef HAVE_STRING_H
+
+/* Define to 1 if you have the `strlcpy' function. */
+#undef HAVE_STRLCPY
+
+/* Define to 1 if you have the `strsep' function. */
+#undef HAVE_STRSEP
+
+/* Define to 1 if you have the `strtok_r' function. */
+#undef HAVE_STRTOK_R
+
+/* Define to 1 if you have the `strtoll' function. */
+#undef HAVE_STRTOLL
+
+/* Define to 1 if the system has the type `struct in6_addr'. */
+#undef HAVE_STRUCT_IN6_ADDR
+
+/* Define to 1 if you have the <sys/devpoll.h> header file. */
+#undef HAVE_SYS_DEVPOLL_H
+
+/* Define to 1 if you have the <sys/epoll.h> header file. */
+#undef HAVE_SYS_EPOLL_H
+
+/* Define to 1 if you have the <sys/event.h> header file. */
+#undef HAVE_SYS_EVENT_H
+
+/* Define to 1 if you have the <sys/ioctl.h> header file. */
+#undef HAVE_SYS_IOCTL_H
+
+/* Define to 1 if you have the <sys/param.h> header file. */
+#undef HAVE_SYS_PARAM_H
+
+/* Define to 1 if you have the <sys/queue.h> header file. */
+#undef HAVE_SYS_QUEUE_H
+
+/* Define to 1 if you have the <sys/select.h> header file. */
+#undef HAVE_SYS_SELECT_H
+
+/* Define to 1 if you have the <sys/socket.h> header file. */
+#undef HAVE_SYS_SOCKET_H
+
+/* Define to 1 if you have the <sys/stat.h> header file. */
+#undef HAVE_SYS_STAT_H
+
+/* Define to 1 if you have the <sys/time.h> header file. */
+#undef HAVE_SYS_TIME_H
+
+/* Define to 1 if you have the <sys/types.h> header file. */
+#undef HAVE_SYS_TYPES_H
+
+/* Define if TAILQ_FOREACH is defined in <sys/queue.h> */
+#undef HAVE_TAILQFOREACH
+
+/* Define if timeradd is defined in <sys/time.h> */
+#undef HAVE_TIMERADD
+
+/* Define if timerclear is defined in <sys/time.h> */
+#undef HAVE_TIMERCLEAR
+
+/* Define if timercmp is defined in <sys/time.h> */
+#undef HAVE_TIMERCMP
+
+/* Define if timerisset is defined in <sys/time.h> */
+#undef HAVE_TIMERISSET
+
+/* Define to 1 if the system has the type `uint16_t'. */
+#undef HAVE_UINT16_T
+
+/* Define to 1 if the system has the type `uint32_t'. */
+#undef HAVE_UINT32_T
+
+/* Define to 1 if the system has the type `uint64_t'. */
+#undef HAVE_UINT64_T
+
+/* Define to 1 if the system has the type `uint8_t'. */
+#undef HAVE_UINT8_T
+
+/* Define to 1 if you have the <unistd.h> header file. */
+#undef HAVE_UNISTD_H
+
+/* Define to 1 if you have the `vasprintf' function. */
+#undef HAVE_VASPRINTF
+
+/* Define if kqueue works correctly with pipes */
+#undef HAVE_WORKING_KQUEUE
+
+/* Name of package */
+#undef PACKAGE
+
+/* Define to the address where bug reports for this package should be sent. */
+#undef PACKAGE_BUGREPORT
+
+/* Define to the full name of this package. */
+#undef PACKAGE_NAME
+
+/* Define to the full name and version of this package. */
+#undef PACKAGE_STRING
+
+/* Define to the one symbol short name of this package. */
+#undef PACKAGE_TARNAME
+
+/* Define to the version of this package. */
+#undef PACKAGE_VERSION
+
+/* The size of a `int', as computed by sizeof. */
+#undef SIZEOF_INT
+
+/* The size of a `long', as computed by sizeof. */
+#undef SIZEOF_LONG
+
+/* The size of a `long long', as computed by sizeof. */
+#undef SIZEOF_LONG_LONG
+
+/* The size of a `short', as computed by sizeof. */
+#undef SIZEOF_SHORT
+
+/* Define to 1 if you have the ANSI C header files. */
+#undef STDC_HEADERS
+
+/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
+#undef TIME_WITH_SYS_TIME
+
+/* Version number of package */
+#undef VERSION
+
+/* Define to appropriate substitue if compiler doesnt have __func__ */
+#undef __func__
+
+/* Define to empty if `const' does not conform to ANSI C. */
+#undef const
+
+/* Define to `__inline__' or `__inline' if that's what the C compiler
+   calls it, or to nothing if 'inline' is not supported under any name.  */
+#ifndef __cplusplus
+#undef inline
+#endif
+
+/* Define to `int' if <sys/types.h> does not define. */
+#undef pid_t
+
+/* Define to `unsigned' if <sys/types.h> does not define. */
+#undef size_t
+
+/* Define to unsigned int if you dont have it */
+#undef socklen_t
diff --git a/libevent/configure b/libevent/configure
new file mode 100644
index 0000000..0a74aec
--- /dev/null
+++ b/libevent/configure
@@ -0,0 +1,9730 @@
+#! /bin/sh
+# Guess values for system-dependent variables and create Makefiles.
+# Generated by GNU Autoconf 2.59.
+#
+# Copyright (C) 2003 Free Software Foundation, Inc.
+# This configure script is free software; the Free Software Foundation
+# gives unlimited permission to copy, distribute and modify it.
+## --------------------- ##
+## M4sh Initialization.  ##
+## --------------------- ##
+
+# Be Bourne compatible
+if test -n "${ZSH_VERSION+set}" && (emulate sh) >/dev/null 2>&1; then
+  emulate sh
+  NULLCMD=:
+  # Zsh 3.x and 4.x performs word splitting on ${1+"$@"}, which
+  # is contrary to our usage.  Disable this feature.
+  alias -g '${1+"$@"}'='"$@"'
+elif test -n "${BASH_VERSION+set}" && (set -o posix) >/dev/null 2>&1; then
+  set -o posix
+fi
+DUALCASE=1; export DUALCASE # for MKS sh
+
+# Support unset when possible.
+if ( (MAIL=60; unset MAIL) || exit) >/dev/null 2>&1; then
+  as_unset=unset
+else
+  as_unset=false
+fi
+
+
+# Work around bugs in pre-3.0 UWIN ksh.
+$as_unset ENV MAIL MAILPATH
+PS1='$ '
+PS2='> '
+PS4='+ '
+
+# NLS nuisances.
+for as_var in \
+  LANG LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION \
+  LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER \
+  LC_TELEPHONE LC_TIME
+do
+  if (set +x; test -z "`(eval $as_var=C; export $as_var) 2>&1`"); then
+    eval $as_var=C; export $as_var
+  else
+    $as_unset $as_var
+  fi
+done
+
+# Required to use basename.
+if expr a : '\(a\)' >/dev/null 2>&1; then
+  as_expr=expr
+else
+  as_expr=false
+fi
+
+if (basename /) >/dev/null 2>&1 && test "X`basename / 2>&1`" = "X/"; then
+  as_basename=basename
+else
+  as_basename=false
+fi
+
+
+# Name of the executable.
+as_me=`$as_basename "$0" ||
+$as_expr X/"$0" : '.*/\([^/][^/]*\)/*$' \| \
+	 X"$0" : 'X\(//\)$' \| \
+	 X"$0" : 'X\(/\)$' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X/"$0" |
+    sed '/^.*\/\([^/][^/]*\)\/*$/{ s//\1/; q; }
+  	  /^X\/\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\/\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+
+
+# PATH needs CR, and LINENO needs CR and PATH.
+# Avoid depending upon Character Ranges.
+as_cr_letters='abcdefghijklmnopqrstuvwxyz'
+as_cr_LETTERS='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
+as_cr_Letters=$as_cr_letters$as_cr_LETTERS
+as_cr_digits='0123456789'
+as_cr_alnum=$as_cr_Letters$as_cr_digits
+
+# The user is always right.
+if test "${PATH_SEPARATOR+set}" != set; then
+  echo "#! /bin/sh" >conf$$.sh
+  echo  "exit 0"   >>conf$$.sh
+  chmod +x conf$$.sh
+  if (PATH="/nonexistent;."; conf$$.sh) >/dev/null 2>&1; then
+    PATH_SEPARATOR=';'
+  else
+    PATH_SEPARATOR=:
+  fi
+  rm -f conf$$.sh
+fi
+
+
+  as_lineno_1=$LINENO
+  as_lineno_2=$LINENO
+  as_lineno_3=`(expr $as_lineno_1 + 1) 2>/dev/null`
+  test "x$as_lineno_1" != "x$as_lineno_2" &&
+  test "x$as_lineno_3"  = "x$as_lineno_2"  || {
+  # Find who we are.  Look in the path if we contain no path at all
+  # relative or not.
+  case $0 in
+    *[\\/]* ) as_myself=$0 ;;
+    *) as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  test -r "$as_dir/$0" && as_myself=$as_dir/$0 && break
+done
+
+       ;;
+  esac
+  # We did not find ourselves, most probably we were run as `sh COMMAND'
+  # in which case we are not to be found in the path.
+  if test "x$as_myself" = x; then
+    as_myself=$0
+  fi
+  if test ! -f "$as_myself"; then
+    { echo "$as_me: error: cannot find myself; rerun with an absolute path" >&2
+   { (exit 1); exit 1; }; }
+  fi
+  case $CONFIG_SHELL in
+  '')
+    as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in /bin$PATH_SEPARATOR/usr/bin$PATH_SEPARATOR$PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for as_base in sh bash ksh sh5; do
+	 case $as_dir in
+	 /*)
+	   if ("$as_dir/$as_base" -c '
+  as_lineno_1=$LINENO
+  as_lineno_2=$LINENO
+  as_lineno_3=`(expr $as_lineno_1 + 1) 2>/dev/null`
+  test "x$as_lineno_1" != "x$as_lineno_2" &&
+  test "x$as_lineno_3"  = "x$as_lineno_2" ') 2>/dev/null; then
+	     $as_unset BASH_ENV || test "${BASH_ENV+set}" != set || { BASH_ENV=; export BASH_ENV; }
+	     $as_unset ENV || test "${ENV+set}" != set || { ENV=; export ENV; }
+	     CONFIG_SHELL=$as_dir/$as_base
+	     export CONFIG_SHELL
+	     exec "$CONFIG_SHELL" "$0" ${1+"$@"}
+	   fi;;
+	 esac
+       done
+done
+;;
+  esac
+
+  # Create $as_me.lineno as a copy of $as_myself, but with $LINENO
+  # uniformly replaced by the line number.  The first 'sed' inserts a
+  # line-number line before each line; the second 'sed' does the real
+  # work.  The second script uses 'N' to pair each line-number line
+  # with the numbered line, and appends trailing '-' during
+  # substitution so that $LINENO is not a special case at line end.
+  # (Raja R Harinath suggested sed '=', and Paul Eggert wrote the
+  # second 'sed' script.  Blame Lee E. McMahon for sed's syntax.  :-)
+  sed '=' <$as_myself |
+    sed '
+      N
+      s,$,-,
+      : loop
+      s,^\(['$as_cr_digits']*\)\(.*\)[$]LINENO\([^'$as_cr_alnum'_]\),\1\2\1\3,
+      t loop
+      s,-$,,
+      s,^['$as_cr_digits']*\n,,
+    ' >$as_me.lineno &&
+  chmod +x $as_me.lineno ||
+    { echo "$as_me: error: cannot create $as_me.lineno; rerun with a POSIX shell" >&2
+   { (exit 1); exit 1; }; }
+
+  # Don't try to exec as it changes $[0], causing all sort of problems
+  # (the dirname of $[0] is not the place where we might find the
+  # original and so on.  Autoconf is especially sensible to this).
+  . ./$as_me.lineno
+  # Exit status is that of the last command.
+  exit
+}
+
+
+case `echo "testing\c"; echo 1,2,3`,`echo -n testing; echo 1,2,3` in
+  *c*,-n*) ECHO_N= ECHO_C='
+' ECHO_T='	' ;;
+  *c*,*  ) ECHO_N=-n ECHO_C= ECHO_T= ;;
+  *)       ECHO_N= ECHO_C='\c' ECHO_T= ;;
+esac
+
+if expr a : '\(a\)' >/dev/null 2>&1; then
+  as_expr=expr
+else
+  as_expr=false
+fi
+
+rm -f conf$$ conf$$.exe conf$$.file
+echo >conf$$.file
+if ln -s conf$$.file conf$$ 2>/dev/null; then
+  # We could just check for DJGPP; but this test a) works b) is more generic
+  # and c) will remain valid once DJGPP supports symlinks (DJGPP 2.04).
+  if test -f conf$$.exe; then
+    # Don't use ln at all; we don't have any links
+    as_ln_s='cp -p'
+  else
+    as_ln_s='ln -s'
+  fi
+elif ln conf$$.file conf$$ 2>/dev/null; then
+  as_ln_s=ln
+else
+  as_ln_s='cp -p'
+fi
+rm -f conf$$ conf$$.exe conf$$.file
+
+if mkdir -p . 2>/dev/null; then
+  as_mkdir_p=:
+else
+  test -d ./-p && rmdir ./-p
+  as_mkdir_p=false
+fi
+
+as_executable_p="test -f"
+
+# Sed expression to map a string onto a valid CPP name.
+as_tr_cpp="eval sed 'y%*$as_cr_letters%P$as_cr_LETTERS%;s%[^_$as_cr_alnum]%_%g'"
+
+# Sed expression to map a string onto a valid variable name.
+as_tr_sh="eval sed 'y%*+%pp%;s%[^_$as_cr_alnum]%_%g'"
+
+
+# IFS
+# We need space, tab and new line, in precisely that order.
+as_nl='
+'
+IFS=" 	$as_nl"
+
+# CDPATH.
+$as_unset CDPATH
+
+
+# Name of the host.
+# hostname on some systems (SVR3.2, Linux) returns a bogus exit status,
+# so uname gets run too.
+ac_hostname=`(hostname || uname -n) 2>/dev/null | sed 1q`
+
+exec 6>&1
+
+#
+# Initializations.
+#
+ac_default_prefix=/usr/local
+ac_config_libobj_dir=.
+cross_compiling=no
+subdirs=
+MFLAGS=
+MAKEFLAGS=
+SHELL=${CONFIG_SHELL-/bin/sh}
+
+# Maximum number of lines to put in a shell here document.
+# This variable seems obsolete.  It should probably be removed, and
+# only ac_max_sed_lines should be used.
+: ${ac_max_here_lines=38}
+
+# Identity of this package.
+PACKAGE_NAME=
+PACKAGE_TARNAME=
+PACKAGE_VERSION=
+PACKAGE_STRING=
+PACKAGE_BUGREPORT=
+
+ac_unique_file="event.c"
+# Factoring default headers for most tests.
+ac_includes_default="\
+#include <stdio.h>
+#if HAVE_SYS_TYPES_H
+# include <sys/types.h>
+#endif
+#if HAVE_SYS_STAT_H
+# include <sys/stat.h>
+#endif
+#if STDC_HEADERS
+# include <stdlib.h>
+# include <stddef.h>
+#else
+# if HAVE_STDLIB_H
+#  include <stdlib.h>
+# endif
+#endif
+#if HAVE_STRING_H
+# if !STDC_HEADERS && HAVE_MEMORY_H
+#  include <memory.h>
+# endif
+# include <string.h>
+#endif
+#if HAVE_STRINGS_H
+# include <strings.h>
+#endif
+#if HAVE_INTTYPES_H
+# include <inttypes.h>
+#else
+# if HAVE_STDINT_H
+#  include <stdint.h>
+# endif
+#endif
+#if HAVE_UNISTD_H
+# include <unistd.h>
+#endif"
+
+ac_subst_vars='SHELL PATH_SEPARATOR PACKAGE_NAME PACKAGE_TARNAME PACKAGE_VERSION PACKAGE_STRING PACKAGE_BUGREPORT exec_prefix prefix program_transform_name bindir sbindir libexecdir datadir sysconfdir sharedstatedir localstatedir libdir includedir oldincludedir infodir mandir build_alias host_alias target_alias DEFS ECHO_C ECHO_N ECHO_T LIBS INSTALL_PROGRAM INSTALL_SCRIPT INSTALL_DATA CYGPATH_W PACKAGE VERSION ACLOCAL AUTOCONF AUTOMAKE AUTOHEADER MAKEINFO install_sh STRIP ac_ct_STRIP INSTALL_STRIP_PROGRAM mkdir_p AWK SET_MAKE am__leading_dot AMTAR am__tar am__untar CC CFLAGS LDFLAGS CPPFLAGS ac_ct_CC EXEEXT OBJEXT DEPDIR am__include am__quote AMDEP_TRUE AMDEP_FALSE AMDEPBACKSLASH CCDEPMODE am__fastdepCC_TRUE am__fastdepCC_FALSE LN_S CPP EGREP RANLIB ac_ct_RANLIB BUILD_WIN32_TRUE BUILD_WIN32_FALSE LIBOBJS LTLIBOBJS'
+ac_subst_files=''
+
+# Initialize some variables set by options.
+ac_init_help=
+ac_init_version=false
+# The variables have the same names as the options, with
+# dashes changed to underlines.
+cache_file=/dev/null
+exec_prefix=NONE
+no_create=
+no_recursion=
+prefix=NONE
+program_prefix=NONE
+program_suffix=NONE
+program_transform_name=s,x,x,
+silent=
+site=
+srcdir=
+verbose=
+x_includes=NONE
+x_libraries=NONE
+
+# Installation directory options.
+# These are left unexpanded so users can "make install exec_prefix=/foo"
+# and all the variables that are supposed to be based on exec_prefix
+# by default will actually change.
+# Use braces instead of parens because sh, perl, etc. also accept them.
+bindir='${exec_prefix}/bin'
+sbindir='${exec_prefix}/sbin'
+libexecdir='${exec_prefix}/libexec'
+datadir='${prefix}/share'
+sysconfdir='${prefix}/etc'
+sharedstatedir='${prefix}/com'
+localstatedir='${prefix}/var'
+libdir='${exec_prefix}/lib'
+includedir='${prefix}/include'
+oldincludedir='/usr/include'
+infodir='${prefix}/info'
+mandir='${prefix}/man'
+
+ac_prev=
+for ac_option
+do
+  # If the previous option needs an argument, assign it.
+  if test -n "$ac_prev"; then
+    eval "$ac_prev=\$ac_option"
+    ac_prev=
+    continue
+  fi
+
+  ac_optarg=`expr "x$ac_option" : 'x[^=]*=\(.*\)'`
+
+  # Accept the important Cygnus configure options, so we can diagnose typos.
+
+  case $ac_option in
+
+  -bindir | --bindir | --bindi | --bind | --bin | --bi)
+    ac_prev=bindir ;;
+  -bindir=* | --bindir=* | --bindi=* | --bind=* | --bin=* | --bi=*)
+    bindir=$ac_optarg ;;
+
+  -build | --build | --buil | --bui | --bu)
+    ac_prev=build_alias ;;
+  -build=* | --build=* | --buil=* | --bui=* | --bu=*)
+    build_alias=$ac_optarg ;;
+
+  -cache-file | --cache-file | --cache-fil | --cache-fi \
+  | --cache-f | --cache- | --cache | --cach | --cac | --ca | --c)
+    ac_prev=cache_file ;;
+  -cache-file=* | --cache-file=* | --cache-fil=* | --cache-fi=* \
+  | --cache-f=* | --cache-=* | --cache=* | --cach=* | --cac=* | --ca=* | --c=*)
+    cache_file=$ac_optarg ;;
+
+  --config-cache | -C)
+    cache_file=config.cache ;;
+
+  -datadir | --datadir | --datadi | --datad | --data | --dat | --da)
+    ac_prev=datadir ;;
+  -datadir=* | --datadir=* | --datadi=* | --datad=* | --data=* | --dat=* \
+  | --da=*)
+    datadir=$ac_optarg ;;
+
+  -disable-* | --disable-*)
+    ac_feature=`expr "x$ac_option" : 'x-*disable-\(.*\)'`
+    # Reject names that are not valid shell variable names.
+    expr "x$ac_feature" : ".*[^-_$as_cr_alnum]" >/dev/null &&
+      { echo "$as_me: error: invalid feature name: $ac_feature" >&2
+   { (exit 1); exit 1; }; }
+    ac_feature=`echo $ac_feature | sed 's/-/_/g'`
+    eval "enable_$ac_feature=no" ;;
+
+  -enable-* | --enable-*)
+    ac_feature=`expr "x$ac_option" : 'x-*enable-\([^=]*\)'`
+    # Reject names that are not valid shell variable names.
+    expr "x$ac_feature" : ".*[^-_$as_cr_alnum]" >/dev/null &&
+      { echo "$as_me: error: invalid feature name: $ac_feature" >&2
+   { (exit 1); exit 1; }; }
+    ac_feature=`echo $ac_feature | sed 's/-/_/g'`
+    case $ac_option in
+      *=*) ac_optarg=`echo "$ac_optarg" | sed "s/'/'\\\\\\\\''/g"`;;
+      *) ac_optarg=yes ;;
+    esac
+    eval "enable_$ac_feature='$ac_optarg'" ;;
+
+  -exec-prefix | --exec_prefix | --exec-prefix | --exec-prefi \
+  | --exec-pref | --exec-pre | --exec-pr | --exec-p | --exec- \
+  | --exec | --exe | --ex)
+    ac_prev=exec_prefix ;;
+  -exec-prefix=* | --exec_prefix=* | --exec-prefix=* | --exec-prefi=* \
+  | --exec-pref=* | --exec-pre=* | --exec-pr=* | --exec-p=* | --exec-=* \
+  | --exec=* | --exe=* | --ex=*)
+    exec_prefix=$ac_optarg ;;
+
+  -gas | --gas | --ga | --g)
+    # Obsolete; use --with-gas.
+    with_gas=yes ;;
+
+  -help | --help | --hel | --he | -h)
+    ac_init_help=long ;;
+  -help=r* | --help=r* | --hel=r* | --he=r* | -hr*)
+    ac_init_help=recursive ;;
+  -help=s* | --help=s* | --hel=s* | --he=s* | -hs*)
+    ac_init_help=short ;;
+
+  -host | --host | --hos | --ho)
+    ac_prev=host_alias ;;
+  -host=* | --host=* | --hos=* | --ho=*)
+    host_alias=$ac_optarg ;;
+
+  -includedir | --includedir | --includedi | --included | --include \
+  | --includ | --inclu | --incl | --inc)
+    ac_prev=includedir ;;
+  -includedir=* | --includedir=* | --includedi=* | --included=* | --include=* \
+  | --includ=* | --inclu=* | --incl=* | --inc=*)
+    includedir=$ac_optarg ;;
+
+  -infodir | --infodir | --infodi | --infod | --info | --inf)
+    ac_prev=infodir ;;
+  -infodir=* | --infodir=* | --infodi=* | --infod=* | --info=* | --inf=*)
+    infodir=$ac_optarg ;;
+
+  -libdir | --libdir | --libdi | --libd)
+    ac_prev=libdir ;;
+  -libdir=* | --libdir=* | --libdi=* | --libd=*)
+    libdir=$ac_optarg ;;
+
+  -libexecdir | --libexecdir | --libexecdi | --libexecd | --libexec \
+  | --libexe | --libex | --libe)
+    ac_prev=libexecdir ;;
+  -libexecdir=* | --libexecdir=* | --libexecdi=* | --libexecd=* | --libexec=* \
+  | --libexe=* | --libex=* | --libe=*)
+    libexecdir=$ac_optarg ;;
+
+  -localstatedir | --localstatedir | --localstatedi | --localstated \
+  | --localstate | --localstat | --localsta | --localst \
+  | --locals | --local | --loca | --loc | --lo)
+    ac_prev=localstatedir ;;
+  -localstatedir=* | --localstatedir=* | --localstatedi=* | --localstated=* \
+  | --localstate=* | --localstat=* | --localsta=* | --localst=* \
+  | --locals=* | --local=* | --loca=* | --loc=* | --lo=*)
+    localstatedir=$ac_optarg ;;
+
+  -mandir | --mandir | --mandi | --mand | --man | --ma | --m)
+    ac_prev=mandir ;;
+  -mandir=* | --mandir=* | --mandi=* | --mand=* | --man=* | --ma=* | --m=*)
+    mandir=$ac_optarg ;;
+
+  -nfp | --nfp | --nf)
+    # Obsolete; use --without-fp.
+    with_fp=no ;;
+
+  -no-create | --no-create | --no-creat | --no-crea | --no-cre \
+  | --no-cr | --no-c | -n)
+    no_create=yes ;;
+
+  -no-recursion | --no-recursion | --no-recursio | --no-recursi \
+  | --no-recurs | --no-recur | --no-recu | --no-rec | --no-re | --no-r)
+    no_recursion=yes ;;
+
+  -oldincludedir | --oldincludedir | --oldincludedi | --oldincluded \
+  | --oldinclude | --oldinclud | --oldinclu | --oldincl | --oldinc \
+  | --oldin | --oldi | --old | --ol | --o)
+    ac_prev=oldincludedir ;;
+  -oldincludedir=* | --oldincludedir=* | --oldincludedi=* | --oldincluded=* \
+  | --oldinclude=* | --oldinclud=* | --oldinclu=* | --oldincl=* | --oldinc=* \
+  | --oldin=* | --oldi=* | --old=* | --ol=* | --o=*)
+    oldincludedir=$ac_optarg ;;
+
+  -prefix | --prefix | --prefi | --pref | --pre | --pr | --p)
+    ac_prev=prefix ;;
+  -prefix=* | --prefix=* | --prefi=* | --pref=* | --pre=* | --pr=* | --p=*)
+    prefix=$ac_optarg ;;
+
+  -program-prefix | --program-prefix | --program-prefi | --program-pref \
+  | --program-pre | --program-pr | --program-p)
+    ac_prev=program_prefix ;;
+  -program-prefix=* | --program-prefix=* | --program-prefi=* \
+  | --program-pref=* | --program-pre=* | --program-pr=* | --program-p=*)
+    program_prefix=$ac_optarg ;;
+
+  -program-suffix | --program-suffix | --program-suffi | --program-suff \
+  | --program-suf | --program-su | --program-s)
+    ac_prev=program_suffix ;;
+  -program-suffix=* | --program-suffix=* | --program-suffi=* \
+  | --program-suff=* | --program-suf=* | --program-su=* | --program-s=*)
+    program_suffix=$ac_optarg ;;
+
+  -program-transform-name | --program-transform-name \
+  | --program-transform-nam | --program-transform-na \
+  | --program-transform-n | --program-transform- \
+  | --program-transform | --program-transfor \
+  | --program-transfo | --program-transf \
+  | --program-trans | --program-tran \
+  | --progr-tra | --program-tr | --program-t)
+    ac_prev=program_transform_name ;;
+  -program-transform-name=* | --program-transform-name=* \
+  | --program-transform-nam=* | --program-transform-na=* \
+  | --program-transform-n=* | --program-transform-=* \
+  | --program-transform=* | --program-transfor=* \
+  | --program-transfo=* | --program-transf=* \
+  | --program-trans=* | --program-tran=* \
+  | --progr-tra=* | --program-tr=* | --program-t=*)
+    program_transform_name=$ac_optarg ;;
+
+  -q | -quiet | --quiet | --quie | --qui | --qu | --q \
+  | -silent | --silent | --silen | --sile | --sil)
+    silent=yes ;;
+
+  -sbindir | --sbindir | --sbindi | --sbind | --sbin | --sbi | --sb)
+    ac_prev=sbindir ;;
+  -sbindir=* | --sbindir=* | --sbindi=* | --sbind=* | --sbin=* \
+  | --sbi=* | --sb=*)
+    sbindir=$ac_optarg ;;
+
+  -sharedstatedir | --sharedstatedir | --sharedstatedi \
+  | --sharedstated | --sharedstate | --sharedstat | --sharedsta \
+  | --sharedst | --shareds | --shared | --share | --shar \
+  | --sha | --sh)
+    ac_prev=sharedstatedir ;;
+  -sharedstatedir=* | --sharedstatedir=* | --sharedstatedi=* \
+  | --sharedstated=* | --sharedstate=* | --sharedstat=* | --sharedsta=* \
+  | --sharedst=* | --shareds=* | --shared=* | --share=* | --shar=* \
+  | --sha=* | --sh=*)
+    sharedstatedir=$ac_optarg ;;
+
+  -site | --site | --sit)
+    ac_prev=site ;;
+  -site=* | --site=* | --sit=*)
+    site=$ac_optarg ;;
+
+  -srcdir | --srcdir | --srcdi | --srcd | --src | --sr)
+    ac_prev=srcdir ;;
+  -srcdir=* | --srcdir=* | --srcdi=* | --srcd=* | --src=* | --sr=*)
+    srcdir=$ac_optarg ;;
+
+  -sysconfdir | --sysconfdir | --sysconfdi | --sysconfd | --sysconf \
+  | --syscon | --sysco | --sysc | --sys | --sy)
+    ac_prev=sysconfdir ;;
+  -sysconfdir=* | --sysconfdir=* | --sysconfdi=* | --sysconfd=* | --sysconf=* \
+  | --syscon=* | --sysco=* | --sysc=* | --sys=* | --sy=*)
+    sysconfdir=$ac_optarg ;;
+
+  -target | --target | --targe | --targ | --tar | --ta | --t)
+    ac_prev=target_alias ;;
+  -target=* | --target=* | --targe=* | --targ=* | --tar=* | --ta=* | --t=*)
+    target_alias=$ac_optarg ;;
+
+  -v | -verbose | --verbose | --verbos | --verbo | --verb)
+    verbose=yes ;;
+
+  -version | --version | --versio | --versi | --vers | -V)
+    ac_init_version=: ;;
+
+  -with-* | --with-*)
+    ac_package=`expr "x$ac_option" : 'x-*with-\([^=]*\)'`
+    # Reject names that are not valid shell variable names.
+    expr "x$ac_package" : ".*[^-_$as_cr_alnum]" >/dev/null &&
+      { echo "$as_me: error: invalid package name: $ac_package" >&2
+   { (exit 1); exit 1; }; }
+    ac_package=`echo $ac_package| sed 's/-/_/g'`
+    case $ac_option in
+      *=*) ac_optarg=`echo "$ac_optarg" | sed "s/'/'\\\\\\\\''/g"`;;
+      *) ac_optarg=yes ;;
+    esac
+    eval "with_$ac_package='$ac_optarg'" ;;
+
+  -without-* | --without-*)
+    ac_package=`expr "x$ac_option" : 'x-*without-\(.*\)'`
+    # Reject names that are not valid shell variable names.
+    expr "x$ac_package" : ".*[^-_$as_cr_alnum]" >/dev/null &&
+      { echo "$as_me: error: invalid package name: $ac_package" >&2
+   { (exit 1); exit 1; }; }
+    ac_package=`echo $ac_package | sed 's/-/_/g'`
+    eval "with_$ac_package=no" ;;
+
+  --x)
+    # Obsolete; use --with-x.
+    with_x=yes ;;
+
+  -x-includes | --x-includes | --x-include | --x-includ | --x-inclu \
+  | --x-incl | --x-inc | --x-in | --x-i)
+    ac_prev=x_includes ;;
+  -x-includes=* | --x-includes=* | --x-include=* | --x-includ=* | --x-inclu=* \
+  | --x-incl=* | --x-inc=* | --x-in=* | --x-i=*)
+    x_includes=$ac_optarg ;;
+
+  -x-libraries | --x-libraries | --x-librarie | --x-librari \
+  | --x-librar | --x-libra | --x-libr | --x-lib | --x-li | --x-l)
+    ac_prev=x_libraries ;;
+  -x-libraries=* | --x-libraries=* | --x-librarie=* | --x-librari=* \
+  | --x-librar=* | --x-libra=* | --x-libr=* | --x-lib=* | --x-li=* | --x-l=*)
+    x_libraries=$ac_optarg ;;
+
+  -*) { echo "$as_me: error: unrecognized option: $ac_option
+Try \`$0 --help' for more information." >&2
+   { (exit 1); exit 1; }; }
+    ;;
+
+  *=*)
+    ac_envvar=`expr "x$ac_option" : 'x\([^=]*\)='`
+    # Reject names that are not valid shell variable names.
+    expr "x$ac_envvar" : ".*[^_$as_cr_alnum]" >/dev/null &&
+      { echo "$as_me: error: invalid variable name: $ac_envvar" >&2
+   { (exit 1); exit 1; }; }
+    ac_optarg=`echo "$ac_optarg" | sed "s/'/'\\\\\\\\''/g"`
+    eval "$ac_envvar='$ac_optarg'"
+    export $ac_envvar ;;
+
+  *)
+    # FIXME: should be removed in autoconf 3.0.
+    echo "$as_me: WARNING: you should use --build, --host, --target" >&2
+    expr "x$ac_option" : ".*[^-._$as_cr_alnum]" >/dev/null &&
+      echo "$as_me: WARNING: invalid host type: $ac_option" >&2
+    : ${build_alias=$ac_option} ${host_alias=$ac_option} ${target_alias=$ac_option}
+    ;;
+
+  esac
+done
+
+if test -n "$ac_prev"; then
+  ac_option=--`echo $ac_prev | sed 's/_/-/g'`
+  { echo "$as_me: error: missing argument to $ac_option" >&2
+   { (exit 1); exit 1; }; }
+fi
+
+# Be sure to have absolute paths.
+for ac_var in exec_prefix prefix
+do
+  eval ac_val=$`echo $ac_var`
+  case $ac_val in
+    [\\/$]* | ?:[\\/]* | NONE | '' ) ;;
+    *)  { echo "$as_me: error: expected an absolute directory name for --$ac_var: $ac_val" >&2
+   { (exit 1); exit 1; }; };;
+  esac
+done
+
+# Be sure to have absolute paths.
+for ac_var in bindir sbindir libexecdir datadir sysconfdir sharedstatedir \
+	      localstatedir libdir includedir oldincludedir infodir mandir
+do
+  eval ac_val=$`echo $ac_var`
+  case $ac_val in
+    [\\/$]* | ?:[\\/]* ) ;;
+    *)  { echo "$as_me: error: expected an absolute directory name for --$ac_var: $ac_val" >&2
+   { (exit 1); exit 1; }; };;
+  esac
+done
+
+# There might be people who depend on the old broken behavior: `$host'
+# used to hold the argument of --host etc.
+# FIXME: To remove some day.
+build=$build_alias
+host=$host_alias
+target=$target_alias
+
+# FIXME: To remove some day.
+if test "x$host_alias" != x; then
+  if test "x$build_alias" = x; then
+    cross_compiling=maybe
+    echo "$as_me: WARNING: If you wanted to set the --build type, don't use --host.
+    If a cross compiler is detected then cross compile mode will be used." >&2
+  elif test "x$build_alias" != "x$host_alias"; then
+    cross_compiling=yes
+  fi
+fi
+
+ac_tool_prefix=
+test -n "$host_alias" && ac_tool_prefix=$host_alias-
+
+test "$silent" = yes && exec 6>/dev/null
+
+
+# Find the source files, if location was not specified.
+if test -z "$srcdir"; then
+  ac_srcdir_defaulted=yes
+  # Try the directory containing this script, then its parent.
+  ac_confdir=`(dirname "$0") 2>/dev/null ||
+$as_expr X"$0" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$0" : 'X\(//\)[^/]' \| \
+	 X"$0" : 'X\(//\)$' \| \
+	 X"$0" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$0" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+  srcdir=$ac_confdir
+  if test ! -r $srcdir/$ac_unique_file; then
+    srcdir=..
+  fi
+else
+  ac_srcdir_defaulted=no
+fi
+if test ! -r $srcdir/$ac_unique_file; then
+  if test "$ac_srcdir_defaulted" = yes; then
+    { echo "$as_me: error: cannot find sources ($ac_unique_file) in $ac_confdir or .." >&2
+   { (exit 1); exit 1; }; }
+  else
+    { echo "$as_me: error: cannot find sources ($ac_unique_file) in $srcdir" >&2
+   { (exit 1); exit 1; }; }
+  fi
+fi
+(cd $srcdir && test -r ./$ac_unique_file) 2>/dev/null ||
+  { echo "$as_me: error: sources are in $srcdir, but \`cd $srcdir' does not work" >&2
+   { (exit 1); exit 1; }; }
+srcdir=`echo "$srcdir" | sed 's%\([^\\/]\)[\\/]*$%\1%'`
+ac_env_build_alias_set=${build_alias+set}
+ac_env_build_alias_value=$build_alias
+ac_cv_env_build_alias_set=${build_alias+set}
+ac_cv_env_build_alias_value=$build_alias
+ac_env_host_alias_set=${host_alias+set}
+ac_env_host_alias_value=$host_alias
+ac_cv_env_host_alias_set=${host_alias+set}
+ac_cv_env_host_alias_value=$host_alias
+ac_env_target_alias_set=${target_alias+set}
+ac_env_target_alias_value=$target_alias
+ac_cv_env_target_alias_set=${target_alias+set}
+ac_cv_env_target_alias_value=$target_alias
+ac_env_CC_set=${CC+set}
+ac_env_CC_value=$CC
+ac_cv_env_CC_set=${CC+set}
+ac_cv_env_CC_value=$CC
+ac_env_CFLAGS_set=${CFLAGS+set}
+ac_env_CFLAGS_value=$CFLAGS
+ac_cv_env_CFLAGS_set=${CFLAGS+set}
+ac_cv_env_CFLAGS_value=$CFLAGS
+ac_env_LDFLAGS_set=${LDFLAGS+set}
+ac_env_LDFLAGS_value=$LDFLAGS
+ac_cv_env_LDFLAGS_set=${LDFLAGS+set}
+ac_cv_env_LDFLAGS_value=$LDFLAGS
+ac_env_CPPFLAGS_set=${CPPFLAGS+set}
+ac_env_CPPFLAGS_value=$CPPFLAGS
+ac_cv_env_CPPFLAGS_set=${CPPFLAGS+set}
+ac_cv_env_CPPFLAGS_value=$CPPFLAGS
+ac_env_CPP_set=${CPP+set}
+ac_env_CPP_value=$CPP
+ac_cv_env_CPP_set=${CPP+set}
+ac_cv_env_CPP_value=$CPP
+
+#
+# Report the --help message.
+#
+if test "$ac_init_help" = "long"; then
+  # Omit some internal or obsolete options to make the list less imposing.
+  # This message is too long to be a string in the A/UX 3.1 sh.
+  cat <<_ACEOF
+\`configure' configures this package to adapt to many kinds of systems.
+
+Usage: $0 [OPTION]... [VAR=VALUE]...
+
+To assign environment variables (e.g., CC, CFLAGS...), specify them as
+VAR=VALUE.  See below for descriptions of some of the useful variables.
+
+Defaults for the options are specified in brackets.
+
+Configuration:
+  -h, --help              display this help and exit
+      --help=short        display options specific to this package
+      --help=recursive    display the short help of all the included packages
+  -V, --version           display version information and exit
+  -q, --quiet, --silent   do not print \`checking...' messages
+      --cache-file=FILE   cache test results in FILE [disabled]
+  -C, --config-cache      alias for \`--cache-file=config.cache'
+  -n, --no-create         do not create output files
+      --srcdir=DIR        find the sources in DIR [configure dir or \`..']
+
+_ACEOF
+
+  cat <<_ACEOF
+Installation directories:
+  --prefix=PREFIX         install architecture-independent files in PREFIX
+			  [$ac_default_prefix]
+  --exec-prefix=EPREFIX   install architecture-dependent files in EPREFIX
+			  [PREFIX]
+
+By default, \`make install' will install all the files in
+\`$ac_default_prefix/bin', \`$ac_default_prefix/lib' etc.  You can specify
+an installation prefix other than \`$ac_default_prefix' using \`--prefix',
+for instance \`--prefix=\$HOME'.
+
+For better control, use the options below.
+
+Fine tuning of the installation directories:
+  --bindir=DIR           user executables [EPREFIX/bin]
+  --sbindir=DIR          system admin executables [EPREFIX/sbin]
+  --libexecdir=DIR       program executables [EPREFIX/libexec]
+  --datadir=DIR          read-only architecture-independent data [PREFIX/share]
+  --sysconfdir=DIR       read-only single-machine data [PREFIX/etc]
+  --sharedstatedir=DIR   modifiable architecture-independent data [PREFIX/com]
+  --localstatedir=DIR    modifiable single-machine data [PREFIX/var]
+  --libdir=DIR           object code libraries [EPREFIX/lib]
+  --includedir=DIR       C header files [PREFIX/include]
+  --oldincludedir=DIR    C header files for non-gcc [/usr/include]
+  --infodir=DIR          info documentation [PREFIX/info]
+  --mandir=DIR           man documentation [PREFIX/man]
+_ACEOF
+
+  cat <<\_ACEOF
+
+Program names:
+  --program-prefix=PREFIX            prepend PREFIX to installed program names
+  --program-suffix=SUFFIX            append SUFFIX to installed program names
+  --program-transform-name=PROGRAM   run sed PROGRAM on installed program names
+_ACEOF
+fi
+
+if test -n "$ac_init_help"; then
+
+  cat <<\_ACEOF
+
+Optional Features:
+  --disable-FEATURE       do not include FEATURE (same as --enable-FEATURE=no)
+  --enable-FEATURE[=ARG]  include FEATURE [ARG=yes]
+  --disable-dependency-tracking  speeds up one-time build
+  --enable-dependency-tracking   do not reject slow dependency extractors
+  --enable-gcc-warnings   enable verbose warnings with GCC
+
+Some influential environment variables:
+  CC          C compiler command
+  CFLAGS      C compiler flags
+  LDFLAGS     linker flags, e.g. -L<lib dir> if you have libraries in a
+              nonstandard directory <lib dir>
+  CPPFLAGS    C/C++ preprocessor flags, e.g. -I<include dir> if you have
+              headers in a nonstandard directory <include dir>
+  CPP         C preprocessor
+
+Use these variables to override the choices made by `configure' or to help
+it to find libraries and programs with nonstandard names/locations.
+
+_ACEOF
+fi
+
+if test "$ac_init_help" = "recursive"; then
+  # If there are subdirs, report their specific --help.
+  ac_popdir=`pwd`
+  for ac_dir in : $ac_subdirs_all; do test "x$ac_dir" = x: && continue
+    test -d $ac_dir || continue
+    ac_builddir=.
+
+if test "$ac_dir" != .; then
+  ac_dir_suffix=/`echo "$ac_dir" | sed 's,^\.[\\/],,'`
+  # A "../" for each directory in $ac_dir_suffix.
+  ac_top_builddir=`echo "$ac_dir_suffix" | sed 's,/[^\\/]*,../,g'`
+else
+  ac_dir_suffix= ac_top_builddir=
+fi
+
+case $srcdir in
+  .)  # No --srcdir option.  We are building in place.
+    ac_srcdir=.
+    if test -z "$ac_top_builddir"; then
+       ac_top_srcdir=.
+    else
+       ac_top_srcdir=`echo $ac_top_builddir | sed 's,/$,,'`
+    fi ;;
+  [\\/]* | ?:[\\/]* )  # Absolute path.
+    ac_srcdir=$srcdir$ac_dir_suffix;
+    ac_top_srcdir=$srcdir ;;
+  *) # Relative path.
+    ac_srcdir=$ac_top_builddir$srcdir$ac_dir_suffix
+    ac_top_srcdir=$ac_top_builddir$srcdir ;;
+esac
+
+# Do not use `cd foo && pwd` to compute absolute paths, because
+# the directories may not exist.
+case `pwd` in
+.) ac_abs_builddir="$ac_dir";;
+*)
+  case "$ac_dir" in
+  .) ac_abs_builddir=`pwd`;;
+  [\\/]* | ?:[\\/]* ) ac_abs_builddir="$ac_dir";;
+  *) ac_abs_builddir=`pwd`/"$ac_dir";;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_builddir=${ac_top_builddir}.;;
+*)
+  case ${ac_top_builddir}. in
+  .) ac_abs_top_builddir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_builddir=${ac_top_builddir}.;;
+  *) ac_abs_top_builddir=$ac_abs_builddir/${ac_top_builddir}.;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_srcdir=$ac_srcdir;;
+*)
+  case $ac_srcdir in
+  .) ac_abs_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_srcdir=$ac_srcdir;;
+  *) ac_abs_srcdir=$ac_abs_builddir/$ac_srcdir;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_srcdir=$ac_top_srcdir;;
+*)
+  case $ac_top_srcdir in
+  .) ac_abs_top_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_srcdir=$ac_top_srcdir;;
+  *) ac_abs_top_srcdir=$ac_abs_builddir/$ac_top_srcdir;;
+  esac;;
+esac
+
+    cd $ac_dir
+    # Check for guested configure; otherwise get Cygnus style configure.
+    if test -f $ac_srcdir/configure.gnu; then
+      echo
+      $SHELL $ac_srcdir/configure.gnu  --help=recursive
+    elif test -f $ac_srcdir/configure; then
+      echo
+      $SHELL $ac_srcdir/configure  --help=recursive
+    elif test -f $ac_srcdir/configure.ac ||
+	   test -f $ac_srcdir/configure.in; then
+      echo
+      $ac_configure --help
+    else
+      echo "$as_me: WARNING: no configuration information is in $ac_dir" >&2
+    fi
+    cd $ac_popdir
+  done
+fi
+
+test -n "$ac_init_help" && exit 0
+if $ac_init_version; then
+  cat <<\_ACEOF
+
+Copyright (C) 2003 Free Software Foundation, Inc.
+This configure script is free software; the Free Software Foundation
+gives unlimited permission to copy, distribute and modify it.
+_ACEOF
+  exit 0
+fi
+exec 5>config.log
+cat >&5 <<_ACEOF
+This file contains any messages produced by compilers while
+running configure, to aid debugging if configure makes a mistake.
+
+It was created by $as_me, which was
+generated by GNU Autoconf 2.59.  Invocation command line was
+
+  $ $0 $@
+
+_ACEOF
+{
+cat <<_ASUNAME
+## --------- ##
+## Platform. ##
+## --------- ##
+
+hostname = `(hostname || uname -n) 2>/dev/null | sed 1q`
+uname -m = `(uname -m) 2>/dev/null || echo unknown`
+uname -r = `(uname -r) 2>/dev/null || echo unknown`
+uname -s = `(uname -s) 2>/dev/null || echo unknown`
+uname -v = `(uname -v) 2>/dev/null || echo unknown`
+
+/usr/bin/uname -p = `(/usr/bin/uname -p) 2>/dev/null || echo unknown`
+/bin/uname -X     = `(/bin/uname -X) 2>/dev/null     || echo unknown`
+
+/bin/arch              = `(/bin/arch) 2>/dev/null              || echo unknown`
+/usr/bin/arch -k       = `(/usr/bin/arch -k) 2>/dev/null       || echo unknown`
+/usr/convex/getsysinfo = `(/usr/convex/getsysinfo) 2>/dev/null || echo unknown`
+hostinfo               = `(hostinfo) 2>/dev/null               || echo unknown`
+/bin/machine           = `(/bin/machine) 2>/dev/null           || echo unknown`
+/usr/bin/oslevel       = `(/usr/bin/oslevel) 2>/dev/null       || echo unknown`
+/bin/universe          = `(/bin/universe) 2>/dev/null          || echo unknown`
+
+_ASUNAME
+
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  echo "PATH: $as_dir"
+done
+
+} >&5
+
+cat >&5 <<_ACEOF
+
+
+## ----------- ##
+## Core tests. ##
+## ----------- ##
+
+_ACEOF
+
+
+# Keep a trace of the command line.
+# Strip out --no-create and --no-recursion so they do not pile up.
+# Strip out --silent because we don't want to record it for future runs.
+# Also quote any args containing shell meta-characters.
+# Make two passes to allow for proper duplicate-argument suppression.
+ac_configure_args=
+ac_configure_args0=
+ac_configure_args1=
+ac_sep=
+ac_must_keep_next=false
+for ac_pass in 1 2
+do
+  for ac_arg
+  do
+    case $ac_arg in
+    -no-create | --no-c* | -n | -no-recursion | --no-r*) continue ;;
+    -q | -quiet | --quiet | --quie | --qui | --qu | --q \
+    | -silent | --silent | --silen | --sile | --sil)
+      continue ;;
+    *" "*|*"	"*|*[\[\]\~\#\$\^\&\*\(\)\{\}\\\|\;\<\>\?\"\']*)
+      ac_arg=`echo "$ac_arg" | sed "s/'/'\\\\\\\\''/g"` ;;
+    esac
+    case $ac_pass in
+    1) ac_configure_args0="$ac_configure_args0 '$ac_arg'" ;;
+    2)
+      ac_configure_args1="$ac_configure_args1 '$ac_arg'"
+      if test $ac_must_keep_next = true; then
+	ac_must_keep_next=false # Got value, back to normal.
+      else
+	case $ac_arg in
+	  *=* | --config-cache | -C | -disable-* | --disable-* \
+	  | -enable-* | --enable-* | -gas | --g* | -nfp | --nf* \
+	  | -q | -quiet | --q* | -silent | --sil* | -v | -verb* \
+	  | -with-* | --with-* | -without-* | --without-* | --x)
+	    case "$ac_configure_args0 " in
+	      "$ac_configure_args1"*" '$ac_arg' "* ) continue ;;
+	    esac
+	    ;;
+	  -* ) ac_must_keep_next=true ;;
+	esac
+      fi
+      ac_configure_args="$ac_configure_args$ac_sep'$ac_arg'"
+      # Get rid of the leading space.
+      ac_sep=" "
+      ;;
+    esac
+  done
+done
+$as_unset ac_configure_args0 || test "${ac_configure_args0+set}" != set || { ac_configure_args0=; export ac_configure_args0; }
+$as_unset ac_configure_args1 || test "${ac_configure_args1+set}" != set || { ac_configure_args1=; export ac_configure_args1; }
+
+# When interrupted or exit'd, cleanup temporary files, and complete
+# config.log.  We remove comments because anyway the quotes in there
+# would cause problems or look ugly.
+# WARNING: Be sure not to use single quotes in there, as some shells,
+# such as our DU 5.0 friend, will then `close' the trap.
+trap 'exit_status=$?
+  # Save into config.log some information that might help in debugging.
+  {
+    echo
+
+    cat <<\_ASBOX
+## ---------------- ##
+## Cache variables. ##
+## ---------------- ##
+_ASBOX
+    echo
+    # The following way of writing the cache mishandles newlines in values,
+{
+  (set) 2>&1 |
+    case `(ac_space='"'"' '"'"'; set | grep ac_space) 2>&1` in
+    *ac_space=\ *)
+      sed -n \
+	"s/'"'"'/'"'"'\\\\'"'"''"'"'/g;
+	  s/^\\([_$as_cr_alnum]*_cv_[_$as_cr_alnum]*\\)=\\(.*\\)/\\1='"'"'\\2'"'"'/p"
+      ;;
+    *)
+      sed -n \
+	"s/^\\([_$as_cr_alnum]*_cv_[_$as_cr_alnum]*\\)=\\(.*\\)/\\1=\\2/p"
+      ;;
+    esac;
+}
+    echo
+
+    cat <<\_ASBOX
+## ----------------- ##
+## Output variables. ##
+## ----------------- ##
+_ASBOX
+    echo
+    for ac_var in $ac_subst_vars
+    do
+      eval ac_val=$`echo $ac_var`
+      echo "$ac_var='"'"'$ac_val'"'"'"
+    done | sort
+    echo
+
+    if test -n "$ac_subst_files"; then
+      cat <<\_ASBOX
+## ------------- ##
+## Output files. ##
+## ------------- ##
+_ASBOX
+      echo
+      for ac_var in $ac_subst_files
+      do
+	eval ac_val=$`echo $ac_var`
+	echo "$ac_var='"'"'$ac_val'"'"'"
+      done | sort
+      echo
+    fi
+
+    if test -s confdefs.h; then
+      cat <<\_ASBOX
+## ----------- ##
+## confdefs.h. ##
+## ----------- ##
+_ASBOX
+      echo
+      sed "/^$/d" confdefs.h | sort
+      echo
+    fi
+    test "$ac_signal" != 0 &&
+      echo "$as_me: caught signal $ac_signal"
+    echo "$as_me: exit $exit_status"
+  } >&5
+  rm -f core *.core &&
+  rm -rf conftest* confdefs* conf$$* $ac_clean_files &&
+    exit $exit_status
+     ' 0
+for ac_signal in 1 2 13 15; do
+  trap 'ac_signal='$ac_signal'; { (exit 1); exit 1; }' $ac_signal
+done
+ac_signal=0
+
+# confdefs.h avoids OS command line length limits that DEFS can exceed.
+rm -rf conftest* confdefs.h
+# AIX cpp loses on an empty file, so make sure it contains at least a newline.
+echo >confdefs.h
+
+# Predefined preprocessor variables.
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE_NAME "$PACKAGE_NAME"
+_ACEOF
+
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE_TARNAME "$PACKAGE_TARNAME"
+_ACEOF
+
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE_VERSION "$PACKAGE_VERSION"
+_ACEOF
+
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE_STRING "$PACKAGE_STRING"
+_ACEOF
+
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE_BUGREPORT "$PACKAGE_BUGREPORT"
+_ACEOF
+
+
+# Let the site file select an alternate cache file if it wants to.
+# Prefer explicitly selected file to automatically selected ones.
+if test -z "$CONFIG_SITE"; then
+  if test "x$prefix" != xNONE; then
+    CONFIG_SITE="$prefix/share/config.site $prefix/etc/config.site"
+  else
+    CONFIG_SITE="$ac_default_prefix/share/config.site $ac_default_prefix/etc/config.site"
+  fi
+fi
+for ac_site_file in $CONFIG_SITE; do
+  if test -r "$ac_site_file"; then
+    { echo "$as_me:$LINENO: loading site script $ac_site_file" >&5
+echo "$as_me: loading site script $ac_site_file" >&6;}
+    sed 's/^/| /' "$ac_site_file" >&5
+    . "$ac_site_file"
+  fi
+done
+
+if test -r "$cache_file"; then
+  # Some versions of bash will fail to source /dev/null (special
+  # files actually), so we avoid doing that.
+  if test -f "$cache_file"; then
+    { echo "$as_me:$LINENO: loading cache $cache_file" >&5
+echo "$as_me: loading cache $cache_file" >&6;}
+    case $cache_file in
+      [\\/]* | ?:[\\/]* ) . $cache_file;;
+      *)                      . ./$cache_file;;
+    esac
+  fi
+else
+  { echo "$as_me:$LINENO: creating cache $cache_file" >&5
+echo "$as_me: creating cache $cache_file" >&6;}
+  >$cache_file
+fi
+
+# Check that the precious variables saved in the cache have kept the same
+# value.
+ac_cache_corrupted=false
+for ac_var in `(set) 2>&1 |
+	       sed -n 's/^ac_env_\([a-zA-Z_0-9]*\)_set=.*/\1/p'`; do
+  eval ac_old_set=\$ac_cv_env_${ac_var}_set
+  eval ac_new_set=\$ac_env_${ac_var}_set
+  eval ac_old_val="\$ac_cv_env_${ac_var}_value"
+  eval ac_new_val="\$ac_env_${ac_var}_value"
+  case $ac_old_set,$ac_new_set in
+    set,)
+      { echo "$as_me:$LINENO: error: \`$ac_var' was set to \`$ac_old_val' in the previous run" >&5
+echo "$as_me: error: \`$ac_var' was set to \`$ac_old_val' in the previous run" >&2;}
+      ac_cache_corrupted=: ;;
+    ,set)
+      { echo "$as_me:$LINENO: error: \`$ac_var' was not set in the previous run" >&5
+echo "$as_me: error: \`$ac_var' was not set in the previous run" >&2;}
+      ac_cache_corrupted=: ;;
+    ,);;
+    *)
+      if test "x$ac_old_val" != "x$ac_new_val"; then
+	{ echo "$as_me:$LINENO: error: \`$ac_var' has changed since the previous run:" >&5
+echo "$as_me: error: \`$ac_var' has changed since the previous run:" >&2;}
+	{ echo "$as_me:$LINENO:   former value:  $ac_old_val" >&5
+echo "$as_me:   former value:  $ac_old_val" >&2;}
+	{ echo "$as_me:$LINENO:   current value: $ac_new_val" >&5
+echo "$as_me:   current value: $ac_new_val" >&2;}
+	ac_cache_corrupted=:
+      fi;;
+  esac
+  # Pass precious variables to config.status.
+  if test "$ac_new_set" = set; then
+    case $ac_new_val in
+    *" "*|*"	"*|*[\[\]\~\#\$\^\&\*\(\)\{\}\\\|\;\<\>\?\"\']*)
+      ac_arg=$ac_var=`echo "$ac_new_val" | sed "s/'/'\\\\\\\\''/g"` ;;
+    *) ac_arg=$ac_var=$ac_new_val ;;
+    esac
+    case " $ac_configure_args " in
+      *" '$ac_arg' "*) ;; # Avoid dups.  Use of quotes ensures accuracy.
+      *) ac_configure_args="$ac_configure_args '$ac_arg'" ;;
+    esac
+  fi
+done
+if $ac_cache_corrupted; then
+  { echo "$as_me:$LINENO: error: changes in the environment can compromise the build" >&5
+echo "$as_me: error: changes in the environment can compromise the build" >&2;}
+  { { echo "$as_me:$LINENO: error: run \`make distclean' and/or \`rm $cache_file' and start over" >&5
+echo "$as_me: error: run \`make distclean' and/or \`rm $cache_file' and start over" >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+ac_ext=c
+ac_cpp='$CPP $CPPFLAGS'
+ac_compile='$CC -c $CFLAGS $CPPFLAGS conftest.$ac_ext >&5'
+ac_link='$CC -o conftest$ac_exeext $CFLAGS $CPPFLAGS $LDFLAGS conftest.$ac_ext $LIBS >&5'
+ac_compiler_gnu=$ac_cv_c_compiler_gnu
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+am__api_version="1.9"
+ac_aux_dir=
+for ac_dir in $srcdir $srcdir/.. $srcdir/../..; do
+  if test -f $ac_dir/install-sh; then
+    ac_aux_dir=$ac_dir
+    ac_install_sh="$ac_aux_dir/install-sh -c"
+    break
+  elif test -f $ac_dir/install.sh; then
+    ac_aux_dir=$ac_dir
+    ac_install_sh="$ac_aux_dir/install.sh -c"
+    break
+  elif test -f $ac_dir/shtool; then
+    ac_aux_dir=$ac_dir
+    ac_install_sh="$ac_aux_dir/shtool install -c"
+    break
+  fi
+done
+if test -z "$ac_aux_dir"; then
+  { { echo "$as_me:$LINENO: error: cannot find install-sh or install.sh in $srcdir $srcdir/.. $srcdir/../.." >&5
+echo "$as_me: error: cannot find install-sh or install.sh in $srcdir $srcdir/.. $srcdir/../.." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+ac_config_guess="$SHELL $ac_aux_dir/config.guess"
+ac_config_sub="$SHELL $ac_aux_dir/config.sub"
+ac_configure="$SHELL $ac_aux_dir/configure" # This should be Cygnus configure.
+
+# Find a good install program.  We prefer a C program (faster),
+# so one script is as good as another.  But avoid the broken or
+# incompatible versions:
+# SysV /etc/install, /usr/sbin/install
+# SunOS /usr/etc/install
+# IRIX /sbin/install
+# AIX /bin/install
+# AmigaOS /C/install, which installs bootblocks on floppy discs
+# AIX 4 /usr/bin/installbsd, which doesn't work without a -g flag
+# AFS /usr/afsws/bin/install, which mishandles nonexistent args
+# SVR4 /usr/ucb/install, which tries to use the nonexistent group "staff"
+# OS/2's system install, which has a completely different semantic
+# ./install, which can be erroneously created by make from ./install.sh.
+echo "$as_me:$LINENO: checking for a BSD-compatible install" >&5
+echo $ECHO_N "checking for a BSD-compatible install... $ECHO_C" >&6
+if test -z "$INSTALL"; then
+if test "${ac_cv_path_install+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  # Account for people who put trailing slashes in PATH elements.
+case $as_dir/ in
+  ./ | .// | /cC/* | \
+  /etc/* | /usr/sbin/* | /usr/etc/* | /sbin/* | /usr/afsws/bin/* | \
+  ?:\\/os2\\/install\\/* | ?:\\/OS2\\/INSTALL\\/* | \
+  /usr/ucb/* ) ;;
+  *)
+    # OSF1 and SCO ODT 3.0 have their own names for install.
+    # Don't use installbsd from OSF since it installs stuff as root
+    # by default.
+    for ac_prog in ginstall scoinst install; do
+      for ac_exec_ext in '' $ac_executable_extensions; do
+	if $as_executable_p "$as_dir/$ac_prog$ac_exec_ext"; then
+	  if test $ac_prog = install &&
+	    grep dspmsg "$as_dir/$ac_prog$ac_exec_ext" >/dev/null 2>&1; then
+	    # AIX install.  It has an incompatible calling convention.
+	    :
+	  elif test $ac_prog = install &&
+	    grep pwplus "$as_dir/$ac_prog$ac_exec_ext" >/dev/null 2>&1; then
+	    # program-specific install script used by HP pwplus--don't use.
+	    :
+	  else
+	    ac_cv_path_install="$as_dir/$ac_prog$ac_exec_ext -c"
+	    break 3
+	  fi
+	fi
+      done
+    done
+    ;;
+esac
+done
+
+
+fi
+  if test "${ac_cv_path_install+set}" = set; then
+    INSTALL=$ac_cv_path_install
+  else
+    # As a last resort, use the slow shell script.  We don't cache a
+    # path for INSTALL within a source directory, because that will
+    # break other packages using the cache if that directory is
+    # removed, or if the path is relative.
+    INSTALL=$ac_install_sh
+  fi
+fi
+echo "$as_me:$LINENO: result: $INSTALL" >&5
+echo "${ECHO_T}$INSTALL" >&6
+
+# Use test -z because SunOS4 sh mishandles braces in ${var-val}.
+# It thinks the first close brace ends the variable substitution.
+test -z "$INSTALL_PROGRAM" && INSTALL_PROGRAM='${INSTALL}'
+
+test -z "$INSTALL_SCRIPT" && INSTALL_SCRIPT='${INSTALL}'
+
+test -z "$INSTALL_DATA" && INSTALL_DATA='${INSTALL} -m 644'
+
+echo "$as_me:$LINENO: checking whether build environment is sane" >&5
+echo $ECHO_N "checking whether build environment is sane... $ECHO_C" >&6
+# Just in case
+sleep 1
+echo timestamp > conftest.file
+# Do `set' in a subshell so we don't clobber the current shell's
+# arguments.  Must try -L first in case configure is actually a
+# symlink; some systems play weird games with the mod time of symlinks
+# (eg FreeBSD returns the mod time of the symlink's containing
+# directory).
+if (
+   set X `ls -Lt $srcdir/configure conftest.file 2> /dev/null`
+   if test "$*" = "X"; then
+      # -L didn't work.
+      set X `ls -t $srcdir/configure conftest.file`
+   fi
+   rm -f conftest.file
+   if test "$*" != "X $srcdir/configure conftest.file" \
+      && test "$*" != "X conftest.file $srcdir/configure"; then
+
+      # If neither matched, then we have a broken ls.  This can happen
+      # if, for instance, CONFIG_SHELL is bash and it inherits a
+      # broken ls alias from the environment.  This has actually
+      # happened.  Such a system could not be considered "sane".
+      { { echo "$as_me:$LINENO: error: ls -t appears to fail.  Make sure there is not a broken
+alias in your environment" >&5
+echo "$as_me: error: ls -t appears to fail.  Make sure there is not a broken
+alias in your environment" >&2;}
+   { (exit 1); exit 1; }; }
+   fi
+
+   test "$2" = conftest.file
+   )
+then
+   # Ok.
+   :
+else
+   { { echo "$as_me:$LINENO: error: newly created file is older than distributed files!
+Check your system clock" >&5
+echo "$as_me: error: newly created file is older than distributed files!
+Check your system clock" >&2;}
+   { (exit 1); exit 1; }; }
+fi
+echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+test "$program_prefix" != NONE &&
+  program_transform_name="s,^,$program_prefix,;$program_transform_name"
+# Use a double $ so make ignores it.
+test "$program_suffix" != NONE &&
+  program_transform_name="s,\$,$program_suffix,;$program_transform_name"
+# Double any \ or $.  echo might interpret backslashes.
+# By default was `s,x,x', remove it if useless.
+cat <<\_ACEOF >conftest.sed
+s/[\\$]/&&/g;s/;s,x,x,$//
+_ACEOF
+program_transform_name=`echo $program_transform_name | sed -f conftest.sed`
+rm conftest.sed
+
+# expand $ac_aux_dir to an absolute path
+am_aux_dir=`cd $ac_aux_dir && pwd`
+
+test x"${MISSING+set}" = xset || MISSING="\${SHELL} $am_aux_dir/missing"
+# Use eval to expand $SHELL
+if eval "$MISSING --run true"; then
+  am_missing_run="$MISSING --run "
+else
+  am_missing_run=
+  { echo "$as_me:$LINENO: WARNING: \`missing' script is too old or missing" >&5
+echo "$as_me: WARNING: \`missing' script is too old or missing" >&2;}
+fi
+
+if mkdir -p --version . >/dev/null 2>&1 && test ! -d ./--version; then
+  # We used to keeping the `.' as first argument, in order to
+  # allow $(mkdir_p) to be used without argument.  As in
+  #   $(mkdir_p) $(somedir)
+  # where $(somedir) is conditionally defined.  However this is wrong
+  # for two reasons:
+  #  1. if the package is installed by a user who cannot write `.'
+  #     make install will fail,
+  #  2. the above comment should most certainly read
+  #     $(mkdir_p) $(DESTDIR)$(somedir)
+  #     so it does not work when $(somedir) is undefined and
+  #     $(DESTDIR) is not.
+  #  To support the latter case, we have to write
+  #     test -z "$(somedir)" || $(mkdir_p) $(DESTDIR)$(somedir),
+  #  so the `.' trick is pointless.
+  mkdir_p='mkdir -p --'
+else
+  # On NextStep and OpenStep, the `mkdir' command does not
+  # recognize any option.  It will interpret all options as
+  # directories to create, and then abort because `.' already
+  # exists.
+  for d in ./-p ./--version;
+  do
+    test -d $d && rmdir $d
+  done
+  # $(mkinstalldirs) is defined by Automake if mkinstalldirs exists.
+  if test -f "$ac_aux_dir/mkinstalldirs"; then
+    mkdir_p='$(mkinstalldirs)'
+  else
+    mkdir_p='$(install_sh) -d'
+  fi
+fi
+
+for ac_prog in gawk mawk nawk awk
+do
+  # Extract the first word of "$ac_prog", so it can be a program name with args.
+set dummy $ac_prog; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_AWK+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$AWK"; then
+  ac_cv_prog_AWK="$AWK" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_AWK="$ac_prog"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+AWK=$ac_cv_prog_AWK
+if test -n "$AWK"; then
+  echo "$as_me:$LINENO: result: $AWK" >&5
+echo "${ECHO_T}$AWK" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  test -n "$AWK" && break
+done
+
+echo "$as_me:$LINENO: checking whether ${MAKE-make} sets \$(MAKE)" >&5
+echo $ECHO_N "checking whether ${MAKE-make} sets \$(MAKE)... $ECHO_C" >&6
+set dummy ${MAKE-make}; ac_make=`echo "$2" | sed 'y,:./+-,___p_,'`
+if eval "test \"\${ac_cv_prog_make_${ac_make}_set+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.make <<\_ACEOF
+all:
+	@echo 'ac_maketemp="$(MAKE)"'
+_ACEOF
+# GNU make sometimes prints "make[1]: Entering...", which would confuse us.
+eval `${MAKE-make} -f conftest.make 2>/dev/null | grep temp=`
+if test -n "$ac_maketemp"; then
+  eval ac_cv_prog_make_${ac_make}_set=yes
+else
+  eval ac_cv_prog_make_${ac_make}_set=no
+fi
+rm -f conftest.make
+fi
+if eval "test \"`echo '$ac_cv_prog_make_'${ac_make}_set`\" = yes"; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+  SET_MAKE=
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+  SET_MAKE="MAKE=${MAKE-make}"
+fi
+
+rm -rf .tst 2>/dev/null
+mkdir .tst 2>/dev/null
+if test -d .tst; then
+  am__leading_dot=.
+else
+  am__leading_dot=_
+fi
+rmdir .tst 2>/dev/null
+
+# test to see if srcdir already configured
+if test "`cd $srcdir && pwd`" != "`pwd`" &&
+   test -f $srcdir/config.status; then
+  { { echo "$as_me:$LINENO: error: source directory already configured; run \"make distclean\" there first" >&5
+echo "$as_me: error: source directory already configured; run \"make distclean\" there first" >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+# test whether we have cygpath
+if test -z "$CYGPATH_W"; then
+  if (cygpath --version) >/dev/null 2>/dev/null; then
+    CYGPATH_W='cygpath -w'
+  else
+    CYGPATH_W=echo
+  fi
+fi
+
+
+# Define the identity of the package.
+ PACKAGE=libevent
+ VERSION=1.4.8-stable
+
+
+cat >>confdefs.h <<_ACEOF
+#define PACKAGE "$PACKAGE"
+_ACEOF
+
+
+cat >>confdefs.h <<_ACEOF
+#define VERSION "$VERSION"
+_ACEOF
+
+# Some tools Automake needs.
+
+ACLOCAL=${ACLOCAL-"${am_missing_run}aclocal-${am__api_version}"}
+
+
+AUTOCONF=${AUTOCONF-"${am_missing_run}autoconf"}
+
+
+AUTOMAKE=${AUTOMAKE-"${am_missing_run}automake-${am__api_version}"}
+
+
+AUTOHEADER=${AUTOHEADER-"${am_missing_run}autoheader"}
+
+
+MAKEINFO=${MAKEINFO-"${am_missing_run}makeinfo"}
+
+install_sh=${install_sh-"$am_aux_dir/install-sh"}
+
+# Installed binaries are usually stripped using `strip' when the user
+# run `make install-strip'.  However `strip' might not be the right
+# tool to use in cross-compilation environments, therefore Automake
+# will honor the `STRIP' environment variable to overrule this program.
+if test "$cross_compiling" != no; then
+  if test -n "$ac_tool_prefix"; then
+  # Extract the first word of "${ac_tool_prefix}strip", so it can be a program name with args.
+set dummy ${ac_tool_prefix}strip; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_STRIP+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$STRIP"; then
+  ac_cv_prog_STRIP="$STRIP" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_STRIP="${ac_tool_prefix}strip"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+STRIP=$ac_cv_prog_STRIP
+if test -n "$STRIP"; then
+  echo "$as_me:$LINENO: result: $STRIP" >&5
+echo "${ECHO_T}$STRIP" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+fi
+if test -z "$ac_cv_prog_STRIP"; then
+  ac_ct_STRIP=$STRIP
+  # Extract the first word of "strip", so it can be a program name with args.
+set dummy strip; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_ac_ct_STRIP+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$ac_ct_STRIP"; then
+  ac_cv_prog_ac_ct_STRIP="$ac_ct_STRIP" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_ac_ct_STRIP="strip"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+  test -z "$ac_cv_prog_ac_ct_STRIP" && ac_cv_prog_ac_ct_STRIP=":"
+fi
+fi
+ac_ct_STRIP=$ac_cv_prog_ac_ct_STRIP
+if test -n "$ac_ct_STRIP"; then
+  echo "$as_me:$LINENO: result: $ac_ct_STRIP" >&5
+echo "${ECHO_T}$ac_ct_STRIP" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  STRIP=$ac_ct_STRIP
+else
+  STRIP="$ac_cv_prog_STRIP"
+fi
+
+fi
+INSTALL_STRIP_PROGRAM="\${SHELL} \$(install_sh) -c -s"
+
+# We need awk for the "check" target.  The system "awk" is bad on
+# some platforms.
+# Always define AMTAR for backward compatibility.
+
+AMTAR=${AMTAR-"${am_missing_run}tar"}
+
+am__tar='${AMTAR} chof - "$$tardir"'; am__untar='${AMTAR} xf -'
+
+
+
+
+
+          ac_config_headers="$ac_config_headers config.h"
+
+
+if test "$prefix" = "NONE"; then
+   prefix="/usr/local"
+fi
+
+ac_ext=c
+ac_cpp='$CPP $CPPFLAGS'
+ac_compile='$CC -c $CFLAGS $CPPFLAGS conftest.$ac_ext >&5'
+ac_link='$CC -o conftest$ac_exeext $CFLAGS $CPPFLAGS $LDFLAGS conftest.$ac_ext $LIBS >&5'
+ac_compiler_gnu=$ac_cv_c_compiler_gnu
+if test -n "$ac_tool_prefix"; then
+  # Extract the first word of "${ac_tool_prefix}gcc", so it can be a program name with args.
+set dummy ${ac_tool_prefix}gcc; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$CC"; then
+  ac_cv_prog_CC="$CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_CC="${ac_tool_prefix}gcc"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+CC=$ac_cv_prog_CC
+if test -n "$CC"; then
+  echo "$as_me:$LINENO: result: $CC" >&5
+echo "${ECHO_T}$CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+fi
+if test -z "$ac_cv_prog_CC"; then
+  ac_ct_CC=$CC
+  # Extract the first word of "gcc", so it can be a program name with args.
+set dummy gcc; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_ac_ct_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$ac_ct_CC"; then
+  ac_cv_prog_ac_ct_CC="$ac_ct_CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_ac_ct_CC="gcc"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+ac_ct_CC=$ac_cv_prog_ac_ct_CC
+if test -n "$ac_ct_CC"; then
+  echo "$as_me:$LINENO: result: $ac_ct_CC" >&5
+echo "${ECHO_T}$ac_ct_CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  CC=$ac_ct_CC
+else
+  CC="$ac_cv_prog_CC"
+fi
+
+if test -z "$CC"; then
+  if test -n "$ac_tool_prefix"; then
+  # Extract the first word of "${ac_tool_prefix}cc", so it can be a program name with args.
+set dummy ${ac_tool_prefix}cc; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$CC"; then
+  ac_cv_prog_CC="$CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_CC="${ac_tool_prefix}cc"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+CC=$ac_cv_prog_CC
+if test -n "$CC"; then
+  echo "$as_me:$LINENO: result: $CC" >&5
+echo "${ECHO_T}$CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+fi
+if test -z "$ac_cv_prog_CC"; then
+  ac_ct_CC=$CC
+  # Extract the first word of "cc", so it can be a program name with args.
+set dummy cc; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_ac_ct_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$ac_ct_CC"; then
+  ac_cv_prog_ac_ct_CC="$ac_ct_CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_ac_ct_CC="cc"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+ac_ct_CC=$ac_cv_prog_ac_ct_CC
+if test -n "$ac_ct_CC"; then
+  echo "$as_me:$LINENO: result: $ac_ct_CC" >&5
+echo "${ECHO_T}$ac_ct_CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  CC=$ac_ct_CC
+else
+  CC="$ac_cv_prog_CC"
+fi
+
+fi
+if test -z "$CC"; then
+  # Extract the first word of "cc", so it can be a program name with args.
+set dummy cc; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$CC"; then
+  ac_cv_prog_CC="$CC" # Let the user override the test.
+else
+  ac_prog_rejected=no
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    if test "$as_dir/$ac_word$ac_exec_ext" = "/usr/ucb/cc"; then
+       ac_prog_rejected=yes
+       continue
+     fi
+    ac_cv_prog_CC="cc"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+if test $ac_prog_rejected = yes; then
+  # We found a bogon in the path, so make sure we never use it.
+  set dummy $ac_cv_prog_CC
+  shift
+  if test $# != 0; then
+    # We chose a different compiler from the bogus one.
+    # However, it has the same basename, so the bogon will be chosen
+    # first if we set CC to just the basename; use the full file name.
+    shift
+    ac_cv_prog_CC="$as_dir/$ac_word${1+' '}$@"
+  fi
+fi
+fi
+fi
+CC=$ac_cv_prog_CC
+if test -n "$CC"; then
+  echo "$as_me:$LINENO: result: $CC" >&5
+echo "${ECHO_T}$CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+fi
+if test -z "$CC"; then
+  if test -n "$ac_tool_prefix"; then
+  for ac_prog in cl
+  do
+    # Extract the first word of "$ac_tool_prefix$ac_prog", so it can be a program name with args.
+set dummy $ac_tool_prefix$ac_prog; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$CC"; then
+  ac_cv_prog_CC="$CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_CC="$ac_tool_prefix$ac_prog"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+CC=$ac_cv_prog_CC
+if test -n "$CC"; then
+  echo "$as_me:$LINENO: result: $CC" >&5
+echo "${ECHO_T}$CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+    test -n "$CC" && break
+  done
+fi
+if test -z "$CC"; then
+  ac_ct_CC=$CC
+  for ac_prog in cl
+do
+  # Extract the first word of "$ac_prog", so it can be a program name with args.
+set dummy $ac_prog; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_ac_ct_CC+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$ac_ct_CC"; then
+  ac_cv_prog_ac_ct_CC="$ac_ct_CC" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_ac_ct_CC="$ac_prog"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+ac_ct_CC=$ac_cv_prog_ac_ct_CC
+if test -n "$ac_ct_CC"; then
+  echo "$as_me:$LINENO: result: $ac_ct_CC" >&5
+echo "${ECHO_T}$ac_ct_CC" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  test -n "$ac_ct_CC" && break
+done
+
+  CC=$ac_ct_CC
+fi
+
+fi
+
+
+test -z "$CC" && { { echo "$as_me:$LINENO: error: no acceptable C compiler found in \$PATH
+See \`config.log' for more details." >&5
+echo "$as_me: error: no acceptable C compiler found in \$PATH
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+
+# Provide some information about the compiler.
+echo "$as_me:$LINENO:" \
+     "checking for C compiler version" >&5
+ac_compiler=`set X $ac_compile; echo $2`
+{ (eval echo "$as_me:$LINENO: \"$ac_compiler --version </dev/null >&5\"") >&5
+  (eval $ac_compiler --version </dev/null >&5) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }
+{ (eval echo "$as_me:$LINENO: \"$ac_compiler -v </dev/null >&5\"") >&5
+  (eval $ac_compiler -v </dev/null >&5) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }
+{ (eval echo "$as_me:$LINENO: \"$ac_compiler -V </dev/null >&5\"") >&5
+  (eval $ac_compiler -V </dev/null >&5) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+  ;
+  return 0;
+}
+_ACEOF
+ac_clean_files_save=$ac_clean_files
+ac_clean_files="$ac_clean_files a.out a.exe b.out"
+# Try to create an executable without -o first, disregard a.out.
+# It will help us diagnose broken compilers, and finding out an intuition
+# of exeext.
+echo "$as_me:$LINENO: checking for C compiler default output file name" >&5
+echo $ECHO_N "checking for C compiler default output file name... $ECHO_C" >&6
+ac_link_default=`echo "$ac_link" | sed 's/ -o *conftest[^ ]*//'`
+if { (eval echo "$as_me:$LINENO: \"$ac_link_default\"") >&5
+  (eval $ac_link_default) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; then
+  # Find the output, starting from the most likely.  This scheme is
+# not robust to junk in `.', hence go to wildcards (a.*) only as a last
+# resort.
+
+# Be careful to initialize this variable, since it used to be cached.
+# Otherwise an old cache value of `no' led to `EXEEXT = no' in a Makefile.
+ac_cv_exeext=
+# b.out is created by i960 compilers.
+for ac_file in a_out.exe a.exe conftest.exe a.out conftest a.* conftest.* b.out
+do
+  test -f "$ac_file" || continue
+  case $ac_file in
+    *.$ac_ext | *.xcoff | *.tds | *.d | *.pdb | *.xSYM | *.bb | *.bbg | *.o | *.obj )
+	;;
+    conftest.$ac_ext )
+	# This is the source file.
+	;;
+    [ab].out )
+	# We found the default executable, but exeext='' is most
+	# certainly right.
+	break;;
+    *.* )
+	ac_cv_exeext=`expr "$ac_file" : '[^.]*\(\..*\)'`
+	# FIXME: I believe we export ac_cv_exeext for Libtool,
+	# but it would be cool to find out if it's true.  Does anybody
+	# maintain Libtool? --akim.
+	export ac_cv_exeext
+	break;;
+    * )
+	break;;
+  esac
+done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+{ { echo "$as_me:$LINENO: error: C compiler cannot create executables
+See \`config.log' for more details." >&5
+echo "$as_me: error: C compiler cannot create executables
+See \`config.log' for more details." >&2;}
+   { (exit 77); exit 77; }; }
+fi
+
+ac_exeext=$ac_cv_exeext
+echo "$as_me:$LINENO: result: $ac_file" >&5
+echo "${ECHO_T}$ac_file" >&6
+
+# Check the compiler produces executables we can run.  If not, either
+# the compiler is broken, or we cross compile.
+echo "$as_me:$LINENO: checking whether the C compiler works" >&5
+echo $ECHO_N "checking whether the C compiler works... $ECHO_C" >&6
+# FIXME: These cross compiler hacks should be removed for Autoconf 3.0
+# If not cross compiling, check that we can run a simple program.
+if test "$cross_compiling" != yes; then
+  if { ac_try='./$ac_file'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+    cross_compiling=no
+  else
+    if test "$cross_compiling" = maybe; then
+	cross_compiling=yes
+    else
+	{ { echo "$as_me:$LINENO: error: cannot run C compiled programs.
+If you meant to cross compile, use \`--host'.
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run C compiled programs.
+If you meant to cross compile, use \`--host'.
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+    fi
+  fi
+fi
+echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+
+rm -f a.out a.exe conftest$ac_cv_exeext b.out
+ac_clean_files=$ac_clean_files_save
+# Check the compiler produces executables we can run.  If not, either
+# the compiler is broken, or we cross compile.
+echo "$as_me:$LINENO: checking whether we are cross compiling" >&5
+echo $ECHO_N "checking whether we are cross compiling... $ECHO_C" >&6
+echo "$as_me:$LINENO: result: $cross_compiling" >&5
+echo "${ECHO_T}$cross_compiling" >&6
+
+echo "$as_me:$LINENO: checking for suffix of executables" >&5
+echo $ECHO_N "checking for suffix of executables... $ECHO_C" >&6
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; then
+  # If both `conftest.exe' and `conftest' are `present' (well, observable)
+# catch `conftest.exe'.  For instance with Cygwin, `ls conftest' will
+# work properly (i.e., refer to `conftest.exe'), while it won't with
+# `rm'.
+for ac_file in conftest.exe conftest conftest.*; do
+  test -f "$ac_file" || continue
+  case $ac_file in
+    *.$ac_ext | *.xcoff | *.tds | *.d | *.pdb | *.xSYM | *.bb | *.bbg | *.o | *.obj ) ;;
+    *.* ) ac_cv_exeext=`expr "$ac_file" : '[^.]*\(\..*\)'`
+	  export ac_cv_exeext
+	  break;;
+    * ) break;;
+  esac
+done
+else
+  { { echo "$as_me:$LINENO: error: cannot compute suffix of executables: cannot compile and link
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute suffix of executables: cannot compile and link
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+rm -f conftest$ac_cv_exeext
+echo "$as_me:$LINENO: result: $ac_cv_exeext" >&5
+echo "${ECHO_T}$ac_cv_exeext" >&6
+
+rm -f conftest.$ac_ext
+EXEEXT=$ac_cv_exeext
+ac_exeext=$EXEEXT
+echo "$as_me:$LINENO: checking for suffix of object files" >&5
+echo $ECHO_N "checking for suffix of object files... $ECHO_C" >&6
+if test "${ac_cv_objext+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.o conftest.obj
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; then
+  for ac_file in `(ls conftest.o conftest.obj; ls conftest.*) 2>/dev/null`; do
+  case $ac_file in
+    *.$ac_ext | *.xcoff | *.tds | *.d | *.pdb | *.xSYM | *.bb | *.bbg ) ;;
+    *) ac_cv_objext=`expr "$ac_file" : '.*\.\(.*\)'`
+       break;;
+  esac
+done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+{ { echo "$as_me:$LINENO: error: cannot compute suffix of object files: cannot compile
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute suffix of object files: cannot compile
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+rm -f conftest.$ac_cv_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_objext" >&5
+echo "${ECHO_T}$ac_cv_objext" >&6
+OBJEXT=$ac_cv_objext
+ac_objext=$OBJEXT
+echo "$as_me:$LINENO: checking whether we are using the GNU C compiler" >&5
+echo $ECHO_N "checking whether we are using the GNU C compiler... $ECHO_C" >&6
+if test "${ac_cv_c_compiler_gnu+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+#ifndef __GNUC__
+       choke me
+#endif
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_compiler_gnu=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_compiler_gnu=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+ac_cv_c_compiler_gnu=$ac_compiler_gnu
+
+fi
+echo "$as_me:$LINENO: result: $ac_cv_c_compiler_gnu" >&5
+echo "${ECHO_T}$ac_cv_c_compiler_gnu" >&6
+GCC=`test $ac_compiler_gnu = yes && echo yes`
+ac_test_CFLAGS=${CFLAGS+set}
+ac_save_CFLAGS=$CFLAGS
+CFLAGS="-g"
+echo "$as_me:$LINENO: checking whether $CC accepts -g" >&5
+echo $ECHO_N "checking whether $CC accepts -g... $ECHO_C" >&6
+if test "${ac_cv_prog_cc_g+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_prog_cc_g=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_prog_cc_g=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_prog_cc_g" >&5
+echo "${ECHO_T}$ac_cv_prog_cc_g" >&6
+if test "$ac_test_CFLAGS" = set; then
+  CFLAGS=$ac_save_CFLAGS
+elif test $ac_cv_prog_cc_g = yes; then
+  if test "$GCC" = yes; then
+    CFLAGS="-g -O2"
+  else
+    CFLAGS="-g"
+  fi
+else
+  if test "$GCC" = yes; then
+    CFLAGS="-O2"
+  else
+    CFLAGS=
+  fi
+fi
+echo "$as_me:$LINENO: checking for $CC option to accept ANSI C" >&5
+echo $ECHO_N "checking for $CC option to accept ANSI C... $ECHO_C" >&6
+if test "${ac_cv_prog_cc_stdc+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_cv_prog_cc_stdc=no
+ac_save_CC=$CC
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <stdarg.h>
+#include <stdio.h>
+#include <sys/types.h>
+#include <sys/stat.h>
+/* Most of the following tests are stolen from RCS 5.7's src/conf.sh.  */
+struct buf { int x; };
+FILE * (*rcsopen) (struct buf *, struct stat *, int);
+static char *e (p, i)
+     char **p;
+     int i;
+{
+  return p[i];
+}
+static char *f (char * (*g) (char **, int), char **p, ...)
+{
+  char *s;
+  va_list v;
+  va_start (v,p);
+  s = g (p, va_arg (v,int));
+  va_end (v);
+  return s;
+}
+
+/* OSF 4.0 Compaq cc is some sort of almost-ANSI by default.  It has
+   function prototypes and stuff, but not '\xHH' hex character constants.
+   These don't provoke an error unfortunately, instead are silently treated
+   as 'x'.  The following induces an error, until -std1 is added to get
+   proper ANSI mode.  Curiously '\x00'!='x' always comes out true, for an
+   array size at least.  It's necessary to write '\x00'==0 to get something
+   that's true only with -std1.  */
+int osf4_cc_array ['\x00' == 0 ? 1 : -1];
+
+int test (int i, double x);
+struct s1 {int (*f) (int a);};
+struct s2 {int (*f) (double a);};
+int pairnames (int, char **, FILE *(*)(struct buf *, struct stat *, int), int, int);
+int argc;
+char **argv;
+int
+main ()
+{
+return f (e, argv, 0) != argv[0]  ||  f (e, argv, 1) != argv[1];
+  ;
+  return 0;
+}
+_ACEOF
+# Don't try gcc -ansi; that turns off useful extensions and
+# breaks some systems' header files.
+# AIX			-qlanglvl=ansi
+# Ultrix and OSF/1	-std1
+# HP-UX 10.20 and later	-Ae
+# HP-UX older versions	-Aa -D_HPUX_SOURCE
+# SVR4			-Xc -D__EXTENSIONS__
+for ac_arg in "" -qlanglvl=ansi -std1 -Ae "-Aa -D_HPUX_SOURCE" "-Xc -D__EXTENSIONS__"
+do
+  CC="$ac_save_CC $ac_arg"
+  rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_prog_cc_stdc=$ac_arg
+break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+fi
+rm -f conftest.err conftest.$ac_objext
+done
+rm -f conftest.$ac_ext conftest.$ac_objext
+CC=$ac_save_CC
+
+fi
+
+case "x$ac_cv_prog_cc_stdc" in
+  x|xno)
+    echo "$as_me:$LINENO: result: none needed" >&5
+echo "${ECHO_T}none needed" >&6 ;;
+  *)
+    echo "$as_me:$LINENO: result: $ac_cv_prog_cc_stdc" >&5
+echo "${ECHO_T}$ac_cv_prog_cc_stdc" >&6
+    CC="$CC $ac_cv_prog_cc_stdc" ;;
+esac
+
+# Some people use a C++ compiler to compile C.  Since we use `exit',
+# in C++ we need to declare it.  In case someone uses the same compiler
+# for both compiling C and C++ we need to have the C++ compiler decide
+# the declaration of exit, since it's the most demanding environment.
+cat >conftest.$ac_ext <<_ACEOF
+#ifndef __cplusplus
+  choke me
+#endif
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  for ac_declaration in \
+   '' \
+   'extern "C" void std::exit (int) throw (); using std::exit;' \
+   'extern "C" void std::exit (int); using std::exit;' \
+   'extern "C" void exit (int) throw ();' \
+   'extern "C" void exit (int);' \
+   'void exit (int);'
+do
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_declaration
+#include <stdlib.h>
+int
+main ()
+{
+exit (42);
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  :
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+continue
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_declaration
+int
+main ()
+{
+exit (42);
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+rm -f conftest*
+if test -n "$ac_declaration"; then
+  echo '#ifdef __cplusplus' >>confdefs.h
+  echo $ac_declaration      >>confdefs.h
+  echo '#endif'             >>confdefs.h
+fi
+
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+ac_ext=c
+ac_cpp='$CPP $CPPFLAGS'
+ac_compile='$CC -c $CFLAGS $CPPFLAGS conftest.$ac_ext >&5'
+ac_link='$CC -o conftest$ac_exeext $CFLAGS $CPPFLAGS $LDFLAGS conftest.$ac_ext $LIBS >&5'
+ac_compiler_gnu=$ac_cv_c_compiler_gnu
+DEPDIR="${am__leading_dot}deps"
+
+          ac_config_commands="$ac_config_commands depfiles"
+
+
+am_make=${MAKE-make}
+cat > confinc << 'END'
+am__doit:
+	@echo done
+.PHONY: am__doit
+END
+# If we don't find an include directive, just comment out the code.
+echo "$as_me:$LINENO: checking for style of include used by $am_make" >&5
+echo $ECHO_N "checking for style of include used by $am_make... $ECHO_C" >&6
+am__include="#"
+am__quote=
+_am_result=none
+# First try GNU make style include.
+echo "include confinc" > confmf
+# We grep out `Entering directory' and `Leaving directory'
+# messages which can occur if `w' ends up in MAKEFLAGS.
+# In particular we don't look at `^make:' because GNU make might
+# be invoked under some other name (usually "gmake"), in which
+# case it prints its new name instead of `make'.
+if test "`$am_make -s -f confmf 2> /dev/null | grep -v 'ing directory'`" = "done"; then
+   am__include=include
+   am__quote=
+   _am_result=GNU
+fi
+# Now try BSD make style include.
+if test "$am__include" = "#"; then
+   echo '.include "confinc"' > confmf
+   if test "`$am_make -s -f confmf 2> /dev/null`" = "done"; then
+      am__include=.include
+      am__quote="\""
+      _am_result=BSD
+   fi
+fi
+
+
+echo "$as_me:$LINENO: result: $_am_result" >&5
+echo "${ECHO_T}$_am_result" >&6
+rm -f confinc confmf
+
+# Check whether --enable-dependency-tracking or --disable-dependency-tracking was given.
+if test "${enable_dependency_tracking+set}" = set; then
+  enableval="$enable_dependency_tracking"
+
+fi;
+if test "x$enable_dependency_tracking" != xno; then
+  am_depcomp="$ac_aux_dir/depcomp"
+  AMDEPBACKSLASH='\'
+fi
+
+
+if test "x$enable_dependency_tracking" != xno; then
+  AMDEP_TRUE=
+  AMDEP_FALSE='#'
+else
+  AMDEP_TRUE='#'
+  AMDEP_FALSE=
+fi
+
+
+
+
+depcc="$CC"   am_compiler_list=
+
+echo "$as_me:$LINENO: checking dependency style of $depcc" >&5
+echo $ECHO_N "checking dependency style of $depcc... $ECHO_C" >&6
+if test "${am_cv_CC_dependencies_compiler_type+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -z "$AMDEP_TRUE" && test -f "$am_depcomp"; then
+  # We make a subdir and do the tests there.  Otherwise we can end up
+  # making bogus files that we don't know about and never remove.  For
+  # instance it was reported that on HP-UX the gcc test will end up
+  # making a dummy file named `D' -- because `-MD' means `put the output
+  # in D'.
+  mkdir conftest.dir
+  # Copy depcomp to subdir because otherwise we won't find it if we're
+  # using a relative directory.
+  cp "$am_depcomp" conftest.dir
+  cd conftest.dir
+  # We will build objects and dependencies in a subdirectory because
+  # it helps to detect inapplicable dependency modes.  For instance
+  # both Tru64's cc and ICC support -MD to output dependencies as a
+  # side effect of compilation, but ICC will put the dependencies in
+  # the current directory while Tru64 will put them in the object
+  # directory.
+  mkdir sub
+
+  am_cv_CC_dependencies_compiler_type=none
+  if test "$am_compiler_list" = ""; then
+     am_compiler_list=`sed -n 's/^#*\([a-zA-Z0-9]*\))$/\1/p' < ./depcomp`
+  fi
+  for depmode in $am_compiler_list; do
+    # Setup a source with many dependencies, because some compilers
+    # like to wrap large dependency lists on column 80 (with \), and
+    # we should not choose a depcomp mode which is confused by this.
+    #
+    # We need to recreate these files for each test, as the compiler may
+    # overwrite some of them when testing with obscure command lines.
+    # This happens at least with the AIX C compiler.
+    : > sub/conftest.c
+    for i in 1 2 3 4 5 6; do
+      echo '#include "conftst'$i'.h"' >> sub/conftest.c
+      # Using `: > sub/conftst$i.h' creates only sub/conftst1.h with
+      # Solaris 8's {/usr,}/bin/sh.
+      touch sub/conftst$i.h
+    done
+    echo "${am__include} ${am__quote}sub/conftest.Po${am__quote}" > confmf
+
+    case $depmode in
+    nosideeffect)
+      # after this tag, mechanisms are not by side-effect, so they'll
+      # only be used when explicitly requested
+      if test "x$enable_dependency_tracking" = xyes; then
+	continue
+      else
+	break
+      fi
+      ;;
+    none) break ;;
+    esac
+    # We check with `-c' and `-o' for the sake of the "dashmstdout"
+    # mode.  It turns out that the SunPro C++ compiler does not properly
+    # handle `-M -o', and we need to detect this.
+    if depmode=$depmode \
+       source=sub/conftest.c object=sub/conftest.${OBJEXT-o} \
+       depfile=sub/conftest.Po tmpdepfile=sub/conftest.TPo \
+       $SHELL ./depcomp $depcc -c -o sub/conftest.${OBJEXT-o} sub/conftest.c \
+         >/dev/null 2>conftest.err &&
+       grep sub/conftst6.h sub/conftest.Po > /dev/null 2>&1 &&
+       grep sub/conftest.${OBJEXT-o} sub/conftest.Po > /dev/null 2>&1 &&
+       ${MAKE-make} -s -f confmf > /dev/null 2>&1; then
+      # icc doesn't choke on unknown options, it will just issue warnings
+      # or remarks (even with -Werror).  So we grep stderr for any message
+      # that says an option was ignored or not supported.
+      # When given -MP, icc 7.0 and 7.1 complain thusly:
+      #   icc: Command line warning: ignoring option '-M'; no argument required
+      # The diagnosis changed in icc 8.0:
+      #   icc: Command line remark: option '-MP' not supported
+      if (grep 'ignoring option' conftest.err ||
+          grep 'not supported' conftest.err) >/dev/null 2>&1; then :; else
+        am_cv_CC_dependencies_compiler_type=$depmode
+        break
+      fi
+    fi
+  done
+
+  cd ..
+  rm -rf conftest.dir
+else
+  am_cv_CC_dependencies_compiler_type=none
+fi
+
+fi
+echo "$as_me:$LINENO: result: $am_cv_CC_dependencies_compiler_type" >&5
+echo "${ECHO_T}$am_cv_CC_dependencies_compiler_type" >&6
+CCDEPMODE=depmode=$am_cv_CC_dependencies_compiler_type
+
+
+
+if
+  test "x$enable_dependency_tracking" != xno \
+  && test "$am_cv_CC_dependencies_compiler_type" = gcc3; then
+  am__fastdepCC_TRUE=
+  am__fastdepCC_FALSE='#'
+else
+  am__fastdepCC_TRUE='#'
+  am__fastdepCC_FALSE=
+fi
+
+
+# Find a good install program.  We prefer a C program (faster),
+# so one script is as good as another.  But avoid the broken or
+# incompatible versions:
+# SysV /etc/install, /usr/sbin/install
+# SunOS /usr/etc/install
+# IRIX /sbin/install
+# AIX /bin/install
+# AmigaOS /C/install, which installs bootblocks on floppy discs
+# AIX 4 /usr/bin/installbsd, which doesn't work without a -g flag
+# AFS /usr/afsws/bin/install, which mishandles nonexistent args
+# SVR4 /usr/ucb/install, which tries to use the nonexistent group "staff"
+# OS/2's system install, which has a completely different semantic
+# ./install, which can be erroneously created by make from ./install.sh.
+echo "$as_me:$LINENO: checking for a BSD-compatible install" >&5
+echo $ECHO_N "checking for a BSD-compatible install... $ECHO_C" >&6
+if test -z "$INSTALL"; then
+if test "${ac_cv_path_install+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  # Account for people who put trailing slashes in PATH elements.
+case $as_dir/ in
+  ./ | .// | /cC/* | \
+  /etc/* | /usr/sbin/* | /usr/etc/* | /sbin/* | /usr/afsws/bin/* | \
+  ?:\\/os2\\/install\\/* | ?:\\/OS2\\/INSTALL\\/* | \
+  /usr/ucb/* ) ;;
+  *)
+    # OSF1 and SCO ODT 3.0 have their own names for install.
+    # Don't use installbsd from OSF since it installs stuff as root
+    # by default.
+    for ac_prog in ginstall scoinst install; do
+      for ac_exec_ext in '' $ac_executable_extensions; do
+	if $as_executable_p "$as_dir/$ac_prog$ac_exec_ext"; then
+	  if test $ac_prog = install &&
+	    grep dspmsg "$as_dir/$ac_prog$ac_exec_ext" >/dev/null 2>&1; then
+	    # AIX install.  It has an incompatible calling convention.
+	    :
+	  elif test $ac_prog = install &&
+	    grep pwplus "$as_dir/$ac_prog$ac_exec_ext" >/dev/null 2>&1; then
+	    # program-specific install script used by HP pwplus--don't use.
+	    :
+	  else
+	    ac_cv_path_install="$as_dir/$ac_prog$ac_exec_ext -c"
+	    break 3
+	  fi
+	fi
+      done
+    done
+    ;;
+esac
+done
+
+
+fi
+  if test "${ac_cv_path_install+set}" = set; then
+    INSTALL=$ac_cv_path_install
+  else
+    # As a last resort, use the slow shell script.  We don't cache a
+    # path for INSTALL within a source directory, because that will
+    # break other packages using the cache if that directory is
+    # removed, or if the path is relative.
+    INSTALL=$ac_install_sh
+  fi
+fi
+echo "$as_me:$LINENO: result: $INSTALL" >&5
+echo "${ECHO_T}$INSTALL" >&6
+
+# Use test -z because SunOS4 sh mishandles braces in ${var-val}.
+# It thinks the first close brace ends the variable substitution.
+test -z "$INSTALL_PROGRAM" && INSTALL_PROGRAM='${INSTALL}'
+
+test -z "$INSTALL_SCRIPT" && INSTALL_SCRIPT='${INSTALL}'
+
+test -z "$INSTALL_DATA" && INSTALL_DATA='${INSTALL} -m 644'
+
+echo "$as_me:$LINENO: checking whether ln -s works" >&5
+echo $ECHO_N "checking whether ln -s works... $ECHO_C" >&6
+LN_S=$as_ln_s
+if test "$LN_S" = "ln -s"; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no, using $LN_S" >&5
+echo "${ECHO_T}no, using $LN_S" >&6
+fi
+
+
+
+ac_ext=c
+ac_cpp='$CPP $CPPFLAGS'
+ac_compile='$CC -c $CFLAGS $CPPFLAGS conftest.$ac_ext >&5'
+ac_link='$CC -o conftest$ac_exeext $CFLAGS $CPPFLAGS $LDFLAGS conftest.$ac_ext $LIBS >&5'
+ac_compiler_gnu=$ac_cv_c_compiler_gnu
+echo "$as_me:$LINENO: checking how to run the C preprocessor" >&5
+echo $ECHO_N "checking how to run the C preprocessor... $ECHO_C" >&6
+# On Suns, sometimes $CPP names a directory.
+if test -n "$CPP" && test -d "$CPP"; then
+  CPP=
+fi
+if test -z "$CPP"; then
+  if test "${ac_cv_prog_CPP+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+      # Double quotes because CPP needs to be expanded
+    for CPP in "$CC -E" "$CC -E -traditional-cpp" "/lib/cpp"
+    do
+      ac_preproc_ok=false
+for ac_c_preproc_warn_flag in '' yes
+do
+  # Use a header file that comes with gcc, so configuring glibc
+  # with a fresh cross-compiler works.
+  # Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+  # <limits.h> exists even on freestanding compilers.
+  # On the NeXT, cc -E runs the code through the compiler's parser,
+  # not just through cpp. "Syntax error" is here to catch this case.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+		     Syntax error
+_ACEOF
+if { (eval echo "$as_me:$LINENO: \"$ac_cpp conftest.$ac_ext\"") >&5
+  (eval $ac_cpp conftest.$ac_ext) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } >/dev/null; then
+  if test -s conftest.err; then
+    ac_cpp_err=$ac_c_preproc_warn_flag
+    ac_cpp_err=$ac_cpp_err$ac_c_werror_flag
+  else
+    ac_cpp_err=
+  fi
+else
+  ac_cpp_err=yes
+fi
+if test -z "$ac_cpp_err"; then
+  :
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+  # Broken: fails on valid input.
+continue
+fi
+rm -f conftest.err conftest.$ac_ext
+
+  # OK, works on sane cases.  Now check whether non-existent headers
+  # can be detected and how.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <ac_nonexistent.h>
+_ACEOF
+if { (eval echo "$as_me:$LINENO: \"$ac_cpp conftest.$ac_ext\"") >&5
+  (eval $ac_cpp conftest.$ac_ext) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } >/dev/null; then
+  if test -s conftest.err; then
+    ac_cpp_err=$ac_c_preproc_warn_flag
+    ac_cpp_err=$ac_cpp_err$ac_c_werror_flag
+  else
+    ac_cpp_err=
+  fi
+else
+  ac_cpp_err=yes
+fi
+if test -z "$ac_cpp_err"; then
+  # Broken: success on invalid input.
+continue
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+  # Passes both tests.
+ac_preproc_ok=:
+break
+fi
+rm -f conftest.err conftest.$ac_ext
+
+done
+# Because of `break', _AC_PREPROC_IFELSE's cleaning code was skipped.
+rm -f conftest.err conftest.$ac_ext
+if $ac_preproc_ok; then
+  break
+fi
+
+    done
+    ac_cv_prog_CPP=$CPP
+
+fi
+  CPP=$ac_cv_prog_CPP
+else
+  ac_cv_prog_CPP=$CPP
+fi
+echo "$as_me:$LINENO: result: $CPP" >&5
+echo "${ECHO_T}$CPP" >&6
+ac_preproc_ok=false
+for ac_c_preproc_warn_flag in '' yes
+do
+  # Use a header file that comes with gcc, so configuring glibc
+  # with a fresh cross-compiler works.
+  # Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+  # <limits.h> exists even on freestanding compilers.
+  # On the NeXT, cc -E runs the code through the compiler's parser,
+  # not just through cpp. "Syntax error" is here to catch this case.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+		     Syntax error
+_ACEOF
+if { (eval echo "$as_me:$LINENO: \"$ac_cpp conftest.$ac_ext\"") >&5
+  (eval $ac_cpp conftest.$ac_ext) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } >/dev/null; then
+  if test -s conftest.err; then
+    ac_cpp_err=$ac_c_preproc_warn_flag
+    ac_cpp_err=$ac_cpp_err$ac_c_werror_flag
+  else
+    ac_cpp_err=
+  fi
+else
+  ac_cpp_err=yes
+fi
+if test -z "$ac_cpp_err"; then
+  :
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+  # Broken: fails on valid input.
+continue
+fi
+rm -f conftest.err conftest.$ac_ext
+
+  # OK, works on sane cases.  Now check whether non-existent headers
+  # can be detected and how.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <ac_nonexistent.h>
+_ACEOF
+if { (eval echo "$as_me:$LINENO: \"$ac_cpp conftest.$ac_ext\"") >&5
+  (eval $ac_cpp conftest.$ac_ext) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } >/dev/null; then
+  if test -s conftest.err; then
+    ac_cpp_err=$ac_c_preproc_warn_flag
+    ac_cpp_err=$ac_cpp_err$ac_c_werror_flag
+  else
+    ac_cpp_err=
+  fi
+else
+  ac_cpp_err=yes
+fi
+if test -z "$ac_cpp_err"; then
+  # Broken: success on invalid input.
+continue
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+  # Passes both tests.
+ac_preproc_ok=:
+break
+fi
+rm -f conftest.err conftest.$ac_ext
+
+done
+# Because of `break', _AC_PREPROC_IFELSE's cleaning code was skipped.
+rm -f conftest.err conftest.$ac_ext
+if $ac_preproc_ok; then
+  :
+else
+  { { echo "$as_me:$LINENO: error: C preprocessor \"$CPP\" fails sanity check
+See \`config.log' for more details." >&5
+echo "$as_me: error: C preprocessor \"$CPP\" fails sanity check
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+ac_ext=c
+ac_cpp='$CPP $CPPFLAGS'
+ac_compile='$CC -c $CFLAGS $CPPFLAGS conftest.$ac_ext >&5'
+ac_link='$CC -o conftest$ac_exeext $CFLAGS $CPPFLAGS $LDFLAGS conftest.$ac_ext $LIBS >&5'
+ac_compiler_gnu=$ac_cv_c_compiler_gnu
+
+
+echo "$as_me:$LINENO: checking for egrep" >&5
+echo $ECHO_N "checking for egrep... $ECHO_C" >&6
+if test "${ac_cv_prog_egrep+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if echo a | (grep -E '(a|b)') >/dev/null 2>&1
+    then ac_cv_prog_egrep='grep -E'
+    else ac_cv_prog_egrep='egrep'
+    fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_prog_egrep" >&5
+echo "${ECHO_T}$ac_cv_prog_egrep" >&6
+ EGREP=$ac_cv_prog_egrep
+
+
+if test $ac_cv_c_compiler_gnu = yes; then
+    echo "$as_me:$LINENO: checking whether $CC needs -traditional" >&5
+echo $ECHO_N "checking whether $CC needs -traditional... $ECHO_C" >&6
+if test "${ac_cv_prog_gcc_traditional+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+    ac_pattern="Autoconf.*'x'"
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <sgtty.h>
+Autoconf TIOCGETP
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "$ac_pattern" >/dev/null 2>&1; then
+  ac_cv_prog_gcc_traditional=yes
+else
+  ac_cv_prog_gcc_traditional=no
+fi
+rm -f conftest*
+
+
+  if test $ac_cv_prog_gcc_traditional = no; then
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <termio.h>
+Autoconf TCGETA
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "$ac_pattern" >/dev/null 2>&1; then
+  ac_cv_prog_gcc_traditional=yes
+fi
+rm -f conftest*
+
+  fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_prog_gcc_traditional" >&5
+echo "${ECHO_T}$ac_cv_prog_gcc_traditional" >&6
+  if test $ac_cv_prog_gcc_traditional = yes; then
+    CC="$CC -traditional"
+  fi
+fi
+
+#if test "$GCC" = yes ; then
+#        CFLAGS="$CFLAGS -Wall"
+#fi
+
+# Check whether --enable-gcc-warnings or --disable-gcc-warnings was given.
+if test "${enable_gcc_warnings+set}" = set; then
+  enableval="$enable_gcc_warnings"
+
+fi;
+
+if test -n "$ac_tool_prefix"; then
+  # Extract the first word of "${ac_tool_prefix}ranlib", so it can be a program name with args.
+set dummy ${ac_tool_prefix}ranlib; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_RANLIB+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$RANLIB"; then
+  ac_cv_prog_RANLIB="$RANLIB" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_RANLIB="${ac_tool_prefix}ranlib"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+fi
+fi
+RANLIB=$ac_cv_prog_RANLIB
+if test -n "$RANLIB"; then
+  echo "$as_me:$LINENO: result: $RANLIB" >&5
+echo "${ECHO_T}$RANLIB" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+fi
+if test -z "$ac_cv_prog_RANLIB"; then
+  ac_ct_RANLIB=$RANLIB
+  # Extract the first word of "ranlib", so it can be a program name with args.
+set dummy ranlib; ac_word=$2
+echo "$as_me:$LINENO: checking for $ac_word" >&5
+echo $ECHO_N "checking for $ac_word... $ECHO_C" >&6
+if test "${ac_cv_prog_ac_ct_RANLIB+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test -n "$ac_ct_RANLIB"; then
+  ac_cv_prog_ac_ct_RANLIB="$ac_ct_RANLIB" # Let the user override the test.
+else
+as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for ac_exec_ext in '' $ac_executable_extensions; do
+  if $as_executable_p "$as_dir/$ac_word$ac_exec_ext"; then
+    ac_cv_prog_ac_ct_RANLIB="ranlib"
+    echo "$as_me:$LINENO: found $as_dir/$ac_word$ac_exec_ext" >&5
+    break 2
+  fi
+done
+done
+
+  test -z "$ac_cv_prog_ac_ct_RANLIB" && ac_cv_prog_ac_ct_RANLIB=":"
+fi
+fi
+ac_ct_RANLIB=$ac_cv_prog_ac_ct_RANLIB
+if test -n "$ac_ct_RANLIB"; then
+  echo "$as_me:$LINENO: result: $ac_ct_RANLIB" >&5
+echo "${ECHO_T}$ac_ct_RANLIB" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+
+  RANLIB=$ac_ct_RANLIB
+else
+  RANLIB="$ac_cv_prog_RANLIB"
+fi
+
+
+
+
+echo "$as_me:$LINENO: checking for socket in -lsocket" >&5
+echo $ECHO_N "checking for socket in -lsocket... $ECHO_C" >&6
+if test "${ac_cv_lib_socket_socket+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_check_lib_save_LIBS=$LIBS
+LIBS="-lsocket  $LIBS"
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char socket ();
+int
+main ()
+{
+socket ();
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_lib_socket_socket=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_lib_socket_socket=no
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+LIBS=$ac_check_lib_save_LIBS
+fi
+echo "$as_me:$LINENO: result: $ac_cv_lib_socket_socket" >&5
+echo "${ECHO_T}$ac_cv_lib_socket_socket" >&6
+if test $ac_cv_lib_socket_socket = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define HAVE_LIBSOCKET 1
+_ACEOF
+
+  LIBS="-lsocket $LIBS"
+
+fi
+
+
+echo "$as_me:$LINENO: checking for inet_aton in -lresolv" >&5
+echo $ECHO_N "checking for inet_aton in -lresolv... $ECHO_C" >&6
+if test "${ac_cv_lib_resolv_inet_aton+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_check_lib_save_LIBS=$LIBS
+LIBS="-lresolv  $LIBS"
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char inet_aton ();
+int
+main ()
+{
+inet_aton ();
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_lib_resolv_inet_aton=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_lib_resolv_inet_aton=no
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+LIBS=$ac_check_lib_save_LIBS
+fi
+echo "$as_me:$LINENO: result: $ac_cv_lib_resolv_inet_aton" >&5
+echo "${ECHO_T}$ac_cv_lib_resolv_inet_aton" >&6
+if test $ac_cv_lib_resolv_inet_aton = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define HAVE_LIBRESOLV 1
+_ACEOF
+
+  LIBS="-lresolv $LIBS"
+
+fi
+
+
+echo "$as_me:$LINENO: checking for clock_gettime in -lrt" >&5
+echo $ECHO_N "checking for clock_gettime in -lrt... $ECHO_C" >&6
+if test "${ac_cv_lib_rt_clock_gettime+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_check_lib_save_LIBS=$LIBS
+LIBS="-lrt  $LIBS"
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char clock_gettime ();
+int
+main ()
+{
+clock_gettime ();
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_lib_rt_clock_gettime=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_lib_rt_clock_gettime=no
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+LIBS=$ac_check_lib_save_LIBS
+fi
+echo "$as_me:$LINENO: result: $ac_cv_lib_rt_clock_gettime" >&5
+echo "${ECHO_T}$ac_cv_lib_rt_clock_gettime" >&6
+if test $ac_cv_lib_rt_clock_gettime = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define HAVE_LIBRT 1
+_ACEOF
+
+  LIBS="-lrt $LIBS"
+
+fi
+
+
+echo "$as_me:$LINENO: checking for inet_ntoa in -lnsl" >&5
+echo $ECHO_N "checking for inet_ntoa in -lnsl... $ECHO_C" >&6
+if test "${ac_cv_lib_nsl_inet_ntoa+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_check_lib_save_LIBS=$LIBS
+LIBS="-lnsl  $LIBS"
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char inet_ntoa ();
+int
+main ()
+{
+inet_ntoa ();
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_lib_nsl_inet_ntoa=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_lib_nsl_inet_ntoa=no
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+LIBS=$ac_check_lib_save_LIBS
+fi
+echo "$as_me:$LINENO: result: $ac_cv_lib_nsl_inet_ntoa" >&5
+echo "${ECHO_T}$ac_cv_lib_nsl_inet_ntoa" >&6
+if test $ac_cv_lib_nsl_inet_ntoa = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define HAVE_LIBNSL 1
+_ACEOF
+
+  LIBS="-lnsl $LIBS"
+
+fi
+
+
+echo "$as_me:$LINENO: checking for ANSI C header files" >&5
+echo $ECHO_N "checking for ANSI C header files... $ECHO_C" >&6
+if test "${ac_cv_header_stdc+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <stdlib.h>
+#include <stdarg.h>
+#include <string.h>
+#include <float.h>
+
+int
+main ()
+{
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_header_stdc=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_header_stdc=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+if test $ac_cv_header_stdc = yes; then
+  # SunOS 4.x string.h does not declare mem*, contrary to ANSI.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <string.h>
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "memchr" >/dev/null 2>&1; then
+  :
+else
+  ac_cv_header_stdc=no
+fi
+rm -f conftest*
+
+fi
+
+if test $ac_cv_header_stdc = yes; then
+  # ISC 2.0.2 stdlib.h does not declare free, contrary to ANSI.
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <stdlib.h>
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "free" >/dev/null 2>&1; then
+  :
+else
+  ac_cv_header_stdc=no
+fi
+rm -f conftest*
+
+fi
+
+if test $ac_cv_header_stdc = yes; then
+  # /bin/cc in Irix-4.0.5 gets non-ANSI ctype macros unless using -ansi.
+  if test "$cross_compiling" = yes; then
+  :
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <ctype.h>
+#if ((' ' & 0x0FF) == 0x020)
+# define ISLOWER(c) ('a' <= (c) && (c) <= 'z')
+# define TOUPPER(c) (ISLOWER(c) ? 'A' + ((c) - 'a') : (c))
+#else
+# define ISLOWER(c) \
+		   (('a' <= (c) && (c) <= 'i') \
+		     || ('j' <= (c) && (c) <= 'r') \
+		     || ('s' <= (c) && (c) <= 'z'))
+# define TOUPPER(c) (ISLOWER(c) ? ((c) | 0x40) : (c))
+#endif
+
+#define XOR(e, f) (((e) && !(f)) || (!(e) && (f)))
+int
+main ()
+{
+  int i;
+  for (i = 0; i < 256; i++)
+    if (XOR (islower (i), ISLOWER (i))
+	|| toupper (i) != TOUPPER (i))
+      exit(2);
+  exit (0);
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  :
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+ac_cv_header_stdc=no
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_header_stdc" >&5
+echo "${ECHO_T}$ac_cv_header_stdc" >&6
+if test $ac_cv_header_stdc = yes; then
+
+cat >>confdefs.h <<\_ACEOF
+#define STDC_HEADERS 1
+_ACEOF
+
+fi
+
+# On IRIX 5.3, sys/types and inttypes.h are conflicting.
+
+
+
+
+
+
+
+
+
+for ac_header in sys/types.h sys/stat.h stdlib.h string.h memory.h strings.h \
+		  inttypes.h stdint.h unistd.h
+do
+as_ac_Header=`echo "ac_cv_header_$ac_header" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_header" >&5
+echo $ECHO_N "checking for $ac_header... $ECHO_C" >&6
+if eval "test \"\${$as_ac_Header+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+
+#include <$ac_header>
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_Header=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_Header=no"
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_Header'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_Header'}'`" >&6
+if test `eval echo '${'$as_ac_Header'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_header" | $as_tr_cpp` 1
+_ACEOF
+
+fi
+
+done
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+for ac_header in fcntl.h stdarg.h inttypes.h stdint.h poll.h signal.h unistd.h sys/epoll.h sys/time.h sys/queue.h sys/event.h sys/param.h sys/ioctl.h sys/select.h sys/devpoll.h port.h netinet/in6.h sys/socket.h
+do
+as_ac_Header=`echo "ac_cv_header_$ac_header" | $as_tr_sh`
+if eval "test \"\${$as_ac_Header+set}\" = set"; then
+  echo "$as_me:$LINENO: checking for $ac_header" >&5
+echo $ECHO_N "checking for $ac_header... $ECHO_C" >&6
+if eval "test \"\${$as_ac_Header+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_Header'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_Header'}'`" >&6
+else
+  # Is the header compilable?
+echo "$as_me:$LINENO: checking $ac_header usability" >&5
+echo $ECHO_N "checking $ac_header usability... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+#include <$ac_header>
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_header_compiler=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_header_compiler=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+echo "$as_me:$LINENO: result: $ac_header_compiler" >&5
+echo "${ECHO_T}$ac_header_compiler" >&6
+
+# Is the header present?
+echo "$as_me:$LINENO: checking $ac_header presence" >&5
+echo $ECHO_N "checking $ac_header presence... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <$ac_header>
+_ACEOF
+if { (eval echo "$as_me:$LINENO: \"$ac_cpp conftest.$ac_ext\"") >&5
+  (eval $ac_cpp conftest.$ac_ext) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } >/dev/null; then
+  if test -s conftest.err; then
+    ac_cpp_err=$ac_c_preproc_warn_flag
+    ac_cpp_err=$ac_cpp_err$ac_c_werror_flag
+  else
+    ac_cpp_err=
+  fi
+else
+  ac_cpp_err=yes
+fi
+if test -z "$ac_cpp_err"; then
+  ac_header_preproc=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+  ac_header_preproc=no
+fi
+rm -f conftest.err conftest.$ac_ext
+echo "$as_me:$LINENO: result: $ac_header_preproc" >&5
+echo "${ECHO_T}$ac_header_preproc" >&6
+
+# So?  What about this header?
+case $ac_header_compiler:$ac_header_preproc:$ac_c_preproc_warn_flag in
+  yes:no: )
+    { echo "$as_me:$LINENO: WARNING: $ac_header: accepted by the compiler, rejected by the preprocessor!" >&5
+echo "$as_me: WARNING: $ac_header: accepted by the compiler, rejected by the preprocessor!" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header: proceeding with the compiler's result" >&5
+echo "$as_me: WARNING: $ac_header: proceeding with the compiler's result" >&2;}
+    ac_header_preproc=yes
+    ;;
+  no:yes:* )
+    { echo "$as_me:$LINENO: WARNING: $ac_header: present but cannot be compiled" >&5
+echo "$as_me: WARNING: $ac_header: present but cannot be compiled" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header:     check for missing prerequisite headers?" >&5
+echo "$as_me: WARNING: $ac_header:     check for missing prerequisite headers?" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header: see the Autoconf documentation" >&5
+echo "$as_me: WARNING: $ac_header: see the Autoconf documentation" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header:     section \"Present But Cannot Be Compiled\"" >&5
+echo "$as_me: WARNING: $ac_header:     section \"Present But Cannot Be Compiled\"" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header: proceeding with the preprocessor's result" >&5
+echo "$as_me: WARNING: $ac_header: proceeding with the preprocessor's result" >&2;}
+    { echo "$as_me:$LINENO: WARNING: $ac_header: in the future, the compiler will take precedence" >&5
+echo "$as_me: WARNING: $ac_header: in the future, the compiler will take precedence" >&2;}
+    (
+      cat <<\_ASBOX
+## ------------------------------------------ ##
+## Report this to the AC_PACKAGE_NAME lists.  ##
+## ------------------------------------------ ##
+_ASBOX
+    ) |
+      sed "s/^/$as_me: WARNING:     /" >&2
+    ;;
+esac
+echo "$as_me:$LINENO: checking for $ac_header" >&5
+echo $ECHO_N "checking for $ac_header... $ECHO_C" >&6
+if eval "test \"\${$as_ac_Header+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  eval "$as_ac_Header=\$ac_header_preproc"
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_Header'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_Header'}'`" >&6
+
+fi
+if test `eval echo '${'$as_ac_Header'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_header" | $as_tr_cpp` 1
+_ACEOF
+
+fi
+
+done
+
+if test "x$ac_cv_header_sys_queue_h" = "xyes"; then
+	echo "$as_me:$LINENO: checking for TAILQ_FOREACH in sys/queue.h" >&5
+echo $ECHO_N "checking for TAILQ_FOREACH in sys/queue.h... $ECHO_C" >&6
+	cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#include <sys/queue.h>
+#ifdef TAILQ_FOREACH
+ yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_TAILQFOREACH 1
+_ACEOF
+
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+fi
+rm -f conftest*
+
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	echo "$as_me:$LINENO: checking for timeradd in sys/time.h" >&5
+echo $ECHO_N "checking for timeradd in sys/time.h... $ECHO_C" >&6
+	cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#include <sys/time.h>
+#ifdef timeradd
+ yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_TIMERADD 1
+_ACEOF
+
+	  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+fi
+rm -f conftest*
+
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	echo "$as_me:$LINENO: checking for timercmp in sys/time.h" >&5
+echo $ECHO_N "checking for timercmp in sys/time.h... $ECHO_C" >&6
+	cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#include <sys/time.h>
+#ifdef timercmp
+ yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_TIMERCMP 1
+_ACEOF
+
+	  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+fi
+rm -f conftest*
+
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	echo "$as_me:$LINENO: checking for timerclear in sys/time.h" >&5
+echo $ECHO_N "checking for timerclear in sys/time.h... $ECHO_C" >&6
+	cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#include <sys/time.h>
+#ifdef timerclear
+ yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_TIMERCLEAR 1
+_ACEOF
+
+	  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+fi
+rm -f conftest*
+
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	echo "$as_me:$LINENO: checking for timerisset in sys/time.h" >&5
+echo $ECHO_N "checking for timerisset in sys/time.h... $ECHO_C" >&6
+	cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#include <sys/time.h>
+#ifdef timerisset
+ yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_TIMERISSET 1
+_ACEOF
+
+	  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+fi
+rm -f conftest*
+
+fi
+
+echo "$as_me:$LINENO: checking for WIN32" >&5
+echo $ECHO_N "checking for WIN32... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+#ifndef WIN32
+die horribly
+#endif
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  bwin32=true; echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+bwin32=false; echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+
+
+if test x$bwin32 = xtrue; then
+  BUILD_WIN32_TRUE=
+  BUILD_WIN32_FALSE='#'
+else
+  BUILD_WIN32_TRUE='#'
+  BUILD_WIN32_FALSE=
+fi
+
+
+echo "$as_me:$LINENO: checking for an ANSI C-conforming const" >&5
+echo $ECHO_N "checking for an ANSI C-conforming const... $ECHO_C" >&6
+if test "${ac_cv_c_const+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+/* FIXME: Include the comments suggested by Paul. */
+#ifndef __cplusplus
+  /* Ultrix mips cc rejects this.  */
+  typedef int charset[2];
+  const charset x;
+  /* SunOS 4.1.1 cc rejects this.  */
+  char const *const *ccp;
+  char **p;
+  /* NEC SVR4.0.2 mips cc rejects this.  */
+  struct point {int x, y;};
+  static struct point const zero = {0,0};
+  /* AIX XL C 1.02.0.0 rejects this.
+     It does not let you subtract one const X* pointer from another in
+     an arm of an if-expression whose if-part is not a constant
+     expression */
+  const char *g = "string";
+  ccp = &g + (g ? g-g : 0);
+  /* HPUX 7.0 cc rejects these. */
+  ++ccp;
+  p = (char**) ccp;
+  ccp = (char const *const *) p;
+  { /* SCO 3.2v4 cc rejects this.  */
+    char *t;
+    char const *s = 0 ? (char *) 0 : (char const *) 0;
+
+    *t++ = 0;
+  }
+  { /* Someone thinks the Sun supposedly-ANSI compiler will reject this.  */
+    int x[] = {25, 17};
+    const int *foo = &x[0];
+    ++foo;
+  }
+  { /* Sun SC1.0 ANSI compiler rejects this -- but not the above. */
+    typedef const int *iptr;
+    iptr p = 0;
+    ++p;
+  }
+  { /* AIX XL C 1.02.0.0 rejects this saying
+       "k.c", line 2.27: 1506-025 (S) Operand must be a modifiable lvalue. */
+    struct s { int j; const int *ap[3]; };
+    struct s *b; b->j = 5;
+  }
+  { /* ULTRIX-32 V3.1 (Rev 9) vcc rejects this */
+    const int foo = 10;
+  }
+#endif
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_c_const=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_c_const=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_c_const" >&5
+echo "${ECHO_T}$ac_cv_c_const" >&6
+if test $ac_cv_c_const = no; then
+
+cat >>confdefs.h <<\_ACEOF
+#define const
+_ACEOF
+
+fi
+
+echo "$as_me:$LINENO: checking for inline" >&5
+echo $ECHO_N "checking for inline... $ECHO_C" >&6
+if test "${ac_cv_c_inline+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  ac_cv_c_inline=no
+for ac_kw in inline __inline__ __inline; do
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifndef __cplusplus
+typedef int foo_t;
+static $ac_kw foo_t static_foo () {return 0; }
+$ac_kw foo_t foo () {return 0; }
+#endif
+
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_c_inline=$ac_kw; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+
+fi
+echo "$as_me:$LINENO: result: $ac_cv_c_inline" >&5
+echo "${ECHO_T}$ac_cv_c_inline" >&6
+
+
+case $ac_cv_c_inline in
+  inline | yes) ;;
+  *)
+    case $ac_cv_c_inline in
+      no) ac_val=;;
+      *) ac_val=$ac_cv_c_inline;;
+    esac
+    cat >>confdefs.h <<_ACEOF
+#ifndef __cplusplus
+#define inline $ac_val
+#endif
+_ACEOF
+    ;;
+esac
+
+echo "$as_me:$LINENO: checking whether time.h and sys/time.h may both be included" >&5
+echo $ECHO_N "checking whether time.h and sys/time.h may both be included... $ECHO_C" >&6
+if test "${ac_cv_header_time+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <sys/types.h>
+#include <sys/time.h>
+#include <time.h>
+
+int
+main ()
+{
+if ((struct tm *) 0)
+return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_header_time=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_header_time=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_header_time" >&5
+echo "${ECHO_T}$ac_cv_header_time" >&6
+if test $ac_cv_header_time = yes; then
+
+cat >>confdefs.h <<\_ACEOF
+#define TIME_WITH_SYS_TIME 1
+_ACEOF
+
+fi
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+
+for ac_func in gettimeofday vasprintf fcntl clock_gettime strtok_r strsep getaddrinfo getnameinfo strlcpy inet_ntop signal sigaction strtoll
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+
+fi
+done
+
+
+echo "$as_me:$LINENO: checking for long" >&5
+echo $ECHO_N "checking for long... $ECHO_C" >&6
+if test "${ac_cv_type_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((long *) 0)
+  return 0;
+if (sizeof (long))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_long=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_long=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_long" >&5
+echo "${ECHO_T}$ac_cv_type_long" >&6
+
+echo "$as_me:$LINENO: checking size of long" >&5
+echo $ECHO_N "checking size of long... $ECHO_C" >&6
+if test "${ac_cv_sizeof_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test "$ac_cv_type_long" = yes; then
+  # The cast to unsigned long works around a bug in the HP C Compiler
+  # version HP92453-01 B.11.11.23709.GP, which incorrectly rejects
+  # declarations like `int a3[[(sizeof (unsigned char)) >= 0]];'.
+  # This bug is HP SR number 8606223364.
+  if test "$cross_compiling" = yes; then
+  # Depending upon the size, compute the lo and hi bounds.
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) >= 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=0 ac_mid=0
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr $ac_mid + 1`
+		    if test $ac_lo -le $ac_mid; then
+		      ac_lo= ac_hi=
+		      break
+		    fi
+		    ac_mid=`expr 2 '*' $ac_mid + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) < 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=-1 ac_mid=-1
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) >= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_hi=`expr '(' $ac_mid ')' - 1`
+		       if test $ac_mid -le $ac_hi; then
+			 ac_lo= ac_hi=
+			 break
+		       fi
+		       ac_mid=`expr 2 '*' $ac_mid`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo= ac_hi=
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+# Binary search between lo and hi bounds.
+while test "x$ac_lo" != "x$ac_hi"; do
+  ac_mid=`expr '(' $ac_hi - $ac_lo ')' / 2 + $ac_lo`
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr '(' $ac_mid ')' + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+case $ac_lo in
+?*) ac_cv_sizeof_long=$ac_lo;;
+'') { { echo "$as_me:$LINENO: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; } ;;
+esac
+else
+  if test "$cross_compiling" = yes; then
+  { { echo "$as_me:$LINENO: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+long longval () { return (long) (sizeof (long)); }
+unsigned long ulongval () { return (long) (sizeof (long)); }
+#include <stdio.h>
+#include <stdlib.h>
+int
+main ()
+{
+
+  FILE *f = fopen ("conftest.val", "w");
+  if (! f)
+    exit (1);
+  if (((long) (sizeof (long))) < 0)
+    {
+      long i = longval ();
+      if (i != ((long) (sizeof (long))))
+	exit (1);
+      fprintf (f, "%ld\n", i);
+    }
+  else
+    {
+      unsigned long i = ulongval ();
+      if (i != ((long) (sizeof (long))))
+	exit (1);
+      fprintf (f, "%lu\n", i);
+    }
+  exit (ferror (f) || fclose (f) != 0);
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_sizeof_long=`cat conftest.val`
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+{ { echo "$as_me:$LINENO: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+rm -f conftest.val
+else
+  ac_cv_sizeof_long=0
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_sizeof_long" >&5
+echo "${ECHO_T}$ac_cv_sizeof_long" >&6
+cat >>confdefs.h <<_ACEOF
+#define SIZEOF_LONG $ac_cv_sizeof_long
+_ACEOF
+
+
+
+if test "x$ac_cv_func_clock_gettime" = "xyes"; then
+
+cat >>confdefs.h <<\_ACEOF
+#define DNS_USE_CPU_CLOCK_FOR_ID 1
+_ACEOF
+
+else
+
+cat >>confdefs.h <<\_ACEOF
+#define DNS_USE_GETTIMEOFDAY_FOR_ID 1
+_ACEOF
+
+fi
+
+echo "$as_me:$LINENO: checking for F_SETFD in fcntl.h" >&5
+echo $ECHO_N "checking for F_SETFD in fcntl.h... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+#define _GNU_SOURCE
+#include <fcntl.h>
+#ifdef F_SETFD
+yes
+#endif
+
+_ACEOF
+if (eval "$ac_cpp conftest.$ac_ext") 2>&5 |
+  $EGREP "yes" >/dev/null 2>&1; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_SETFD 1
+_ACEOF
+
+	  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+rm -f conftest*
+
+
+needsignal=no
+haveselect=no
+
+for ac_func in select
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+ haveselect=yes
+fi
+done
+
+if test "x$haveselect" = "xyes" ; then
+	case $LIBOBJS in
+    "select.$ac_objext"   | \
+  *" select.$ac_objext"   | \
+    "select.$ac_objext "* | \
+  *" select.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS select.$ac_objext" ;;
+esac
+
+	needsignal=yes
+fi
+
+havepoll=no
+
+for ac_func in poll
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+ havepoll=yes
+fi
+done
+
+if test "x$havepoll" = "xyes" ; then
+	case $LIBOBJS in
+    "poll.$ac_objext"   | \
+  *" poll.$ac_objext"   | \
+    "poll.$ac_objext "* | \
+  *" poll.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS poll.$ac_objext" ;;
+esac
+
+	needsignal=yes
+fi
+
+haveepoll=no
+
+for ac_func in epoll_ctl
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+ haveepoll=yes
+fi
+done
+
+if test "x$haveepoll" = "xyes" ; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_EPOLL 1
+_ACEOF
+
+	case $LIBOBJS in
+    "epoll.$ac_objext"   | \
+  *" epoll.$ac_objext"   | \
+    "epoll.$ac_objext "* | \
+  *" epoll.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS epoll.$ac_objext" ;;
+esac
+
+	needsignal=yes
+fi
+
+havedevpoll=no
+if test "x$ac_cv_header_sys_devpoll_h" = "xyes"; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_DEVPOLL 1
+_ACEOF
+
+        case $LIBOBJS in
+    "devpoll.$ac_objext"   | \
+  *" devpoll.$ac_objext"   | \
+    "devpoll.$ac_objext "* | \
+  *" devpoll.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS devpoll.$ac_objext" ;;
+esac
+
+fi
+
+havekqueue=no
+if test "x$ac_cv_header_sys_event_h" = "xyes"; then
+
+for ac_func in kqueue
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+ havekqueue=yes
+fi
+done
+
+	if test "x$havekqueue" = "xyes" ; then
+		echo "$as_me:$LINENO: checking for working kqueue" >&5
+echo $ECHO_N "checking for working kqueue... $ECHO_C" >&6
+		if test "$cross_compiling" = yes; then
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <sys/types.h>
+#include <sys/time.h>
+#include <sys/event.h>
+#include <stdio.h>
+#include <unistd.h>
+#include <fcntl.h>
+
+int
+main(int argc, char **argv)
+{
+	int kq;
+	int n;
+	int fd[2];
+	struct kevent ev;
+	struct timespec ts;
+	char buf[8000];
+
+	if (pipe(fd) == -1)
+		exit(1);
+	if (fcntl(fd[1], F_SETFL, O_NONBLOCK) == -1)
+		exit(1);
+
+	while ((n = write(fd[1], buf, sizeof(buf))) == sizeof(buf))
+		;
+
+        if ((kq = kqueue()) == -1)
+		exit(1);
+
+	ev.ident = fd[1];
+	ev.filter = EVFILT_WRITE;
+	ev.flags = EV_ADD | EV_ENABLE;
+	n = kevent(kq, &ev, 1, NULL, 0, NULL);
+	if (n == -1)
+		exit(1);
+
+	read(fd[0], buf, sizeof(buf));
+
+	ts.tv_sec = 0;
+	ts.tv_nsec = 0;
+	n = kevent(kq, NULL, 0, &ev, 1, &ts);
+	if (n == -1 || n == 0)
+		exit(1);
+
+	exit(0);
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_WORKING_KQUEUE 1
+_ACEOF
+
+    case $LIBOBJS in
+    "kqueue.$ac_objext"   | \
+  *" kqueue.$ac_objext"   | \
+    "kqueue.$ac_objext "* | \
+  *" kqueue.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS kqueue.$ac_objext" ;;
+esac
+
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+	fi
+fi
+
+haveepollsyscall=no
+if test "x$ac_cv_header_sys_epoll_h" = "xyes"; then
+	if test "x$haveepoll" = "xno" ; then
+		echo "$as_me:$LINENO: checking for epoll system call" >&5
+echo $ECHO_N "checking for epoll system call... $ECHO_C" >&6
+		if test "$cross_compiling" = yes; then
+  echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#include <stdint.h>
+#include <sys/param.h>
+#include <sys/types.h>
+#include <sys/syscall.h>
+#include <sys/epoll.h>
+#include <unistd.h>
+
+int
+epoll_create(int size)
+{
+	return (syscall(__NR_epoll_create, size));
+}
+
+int
+main(int argc, char **argv)
+{
+	int epfd;
+
+	epfd = epoll_create(256);
+	exit (epfd == -1 ? 1 : 0);
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_EPOLL 1
+_ACEOF
+
+    needsignal=yes
+    case $LIBOBJS in
+    "epoll_sub.$ac_objext"   | \
+  *" epoll_sub.$ac_objext"   | \
+    "epoll_sub.$ac_objext "* | \
+  *" epoll_sub.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS epoll_sub.$ac_objext" ;;
+esac
+
+    case $LIBOBJS in
+    "epoll.$ac_objext"   | \
+  *" epoll.$ac_objext"   | \
+    "epoll.$ac_objext "* | \
+  *" epoll.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS epoll.$ac_objext" ;;
+esac
+
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+	fi
+fi
+
+haveeventports=no
+
+for ac_func in port_create
+do
+as_ac_var=`echo "ac_cv_func_$ac_func" | $as_tr_sh`
+echo "$as_me:$LINENO: checking for $ac_func" >&5
+echo $ECHO_N "checking for $ac_func... $ECHO_C" >&6
+if eval "test \"\${$as_ac_var+set}\" = set"; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+/* Define $ac_func to an innocuous variant, in case <limits.h> declares $ac_func.
+   For example, HP-UX 11i <limits.h> declares gettimeofday.  */
+#define $ac_func innocuous_$ac_func
+
+/* System header to define __stub macros and hopefully few prototypes,
+    which can conflict with char $ac_func (); below.
+    Prefer <limits.h> to <assert.h> if __STDC__ is defined, since
+    <limits.h> exists even on freestanding compilers.  */
+
+#ifdef __STDC__
+# include <limits.h>
+#else
+# include <assert.h>
+#endif
+
+#undef $ac_func
+
+/* Override any gcc2 internal prototype to avoid an error.  */
+#ifdef __cplusplus
+extern "C"
+{
+#endif
+/* We use char because int might match the return type of a gcc2
+   builtin and then its argument prototype would still apply.  */
+char $ac_func ();
+/* The GNU C library defines this for functions which it implements
+    to always fail with ENOSYS.  Some functions are actually named
+    something starting with __ and the normal name is an alias.  */
+#if defined (__stub_$ac_func) || defined (__stub___$ac_func)
+choke me
+#else
+char (*f) () = $ac_func;
+#endif
+#ifdef __cplusplus
+}
+#endif
+
+int
+main ()
+{
+return f != $ac_func;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  eval "$as_ac_var=yes"
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+eval "$as_ac_var=no"
+fi
+rm -f conftest.err conftest.$ac_objext \
+      conftest$ac_exeext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: `eval echo '${'$as_ac_var'}'`" >&5
+echo "${ECHO_T}`eval echo '${'$as_ac_var'}'`" >&6
+if test `eval echo '${'$as_ac_var'}'` = yes; then
+  cat >>confdefs.h <<_ACEOF
+#define `echo "HAVE_$ac_func" | $as_tr_cpp` 1
+_ACEOF
+ haveeventports=yes
+fi
+done
+
+if test "x$haveeventports" = "xyes" ; then
+
+cat >>confdefs.h <<\_ACEOF
+#define HAVE_EVENT_PORTS 1
+_ACEOF
+
+	case $LIBOBJS in
+    "evport.$ac_objext"   | \
+  *" evport.$ac_objext"   | \
+    "evport.$ac_objext "* | \
+  *" evport.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS evport.$ac_objext" ;;
+esac
+
+	needsignal=yes
+fi
+if test "x$bwin32" = "xtrue"; then
+	needsignal=yes
+fi
+if test "x$bwin32" = "xtrue"; then
+	needsignal=yes
+fi
+if test "x$needsignal" = "xyes" ; then
+	case $LIBOBJS in
+    "signal.$ac_objext"   | \
+  *" signal.$ac_objext"   | \
+    "signal.$ac_objext "* | \
+  *" signal.$ac_objext "* ) ;;
+  *) LIBOBJS="$LIBOBJS signal.$ac_objext" ;;
+esac
+
+fi
+
+echo "$as_me:$LINENO: checking for pid_t" >&5
+echo $ECHO_N "checking for pid_t... $ECHO_C" >&6
+if test "${ac_cv_type_pid_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((pid_t *) 0)
+  return 0;
+if (sizeof (pid_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_pid_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_pid_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_pid_t" >&5
+echo "${ECHO_T}$ac_cv_type_pid_t" >&6
+if test $ac_cv_type_pid_t = yes; then
+  :
+else
+
+cat >>confdefs.h <<_ACEOF
+#define pid_t int
+_ACEOF
+
+fi
+
+echo "$as_me:$LINENO: checking for size_t" >&5
+echo $ECHO_N "checking for size_t... $ECHO_C" >&6
+if test "${ac_cv_type_size_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((size_t *) 0)
+  return 0;
+if (sizeof (size_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_size_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_size_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_size_t" >&5
+echo "${ECHO_T}$ac_cv_type_size_t" >&6
+if test $ac_cv_type_size_t = yes; then
+  :
+else
+
+cat >>confdefs.h <<_ACEOF
+#define size_t unsigned
+_ACEOF
+
+fi
+
+echo "$as_me:$LINENO: checking for uint64_t" >&5
+echo $ECHO_N "checking for uint64_t... $ECHO_C" >&6
+if test "${ac_cv_type_uint64_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+
+int
+main ()
+{
+if ((uint64_t *) 0)
+  return 0;
+if (sizeof (uint64_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_uint64_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_uint64_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_uint64_t" >&5
+echo "${ECHO_T}$ac_cv_type_uint64_t" >&6
+if test $ac_cv_type_uint64_t = yes; then
+
+cat >>confdefs.h <<_ACEOF
+#define HAVE_UINT64_T 1
+_ACEOF
+
+
+fi
+echo "$as_me:$LINENO: checking for uint32_t" >&5
+echo $ECHO_N "checking for uint32_t... $ECHO_C" >&6
+if test "${ac_cv_type_uint32_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+
+int
+main ()
+{
+if ((uint32_t *) 0)
+  return 0;
+if (sizeof (uint32_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_uint32_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_uint32_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_uint32_t" >&5
+echo "${ECHO_T}$ac_cv_type_uint32_t" >&6
+if test $ac_cv_type_uint32_t = yes; then
+
+cat >>confdefs.h <<_ACEOF
+#define HAVE_UINT32_T 1
+_ACEOF
+
+
+fi
+echo "$as_me:$LINENO: checking for uint16_t" >&5
+echo $ECHO_N "checking for uint16_t... $ECHO_C" >&6
+if test "${ac_cv_type_uint16_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+
+int
+main ()
+{
+if ((uint16_t *) 0)
+  return 0;
+if (sizeof (uint16_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_uint16_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_uint16_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_uint16_t" >&5
+echo "${ECHO_T}$ac_cv_type_uint16_t" >&6
+if test $ac_cv_type_uint16_t = yes; then
+
+cat >>confdefs.h <<_ACEOF
+#define HAVE_UINT16_T 1
+_ACEOF
+
+
+fi
+echo "$as_me:$LINENO: checking for uint8_t" >&5
+echo $ECHO_N "checking for uint8_t... $ECHO_C" >&6
+if test "${ac_cv_type_uint8_t+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+
+int
+main ()
+{
+if ((uint8_t *) 0)
+  return 0;
+if (sizeof (uint8_t))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_uint8_t=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_uint8_t=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_uint8_t" >&5
+echo "${ECHO_T}$ac_cv_type_uint8_t" >&6
+if test $ac_cv_type_uint8_t = yes; then
+
+cat >>confdefs.h <<_ACEOF
+#define HAVE_UINT8_T 1
+_ACEOF
+
+
+fi
+
+echo "$as_me:$LINENO: checking for long long" >&5
+echo $ECHO_N "checking for long long... $ECHO_C" >&6
+if test "${ac_cv_type_long_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((long long *) 0)
+  return 0;
+if (sizeof (long long))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_long_long=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_long_long=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_long_long" >&5
+echo "${ECHO_T}$ac_cv_type_long_long" >&6
+
+echo "$as_me:$LINENO: checking size of long long" >&5
+echo $ECHO_N "checking size of long long... $ECHO_C" >&6
+if test "${ac_cv_sizeof_long_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test "$ac_cv_type_long_long" = yes; then
+  # The cast to unsigned long works around a bug in the HP C Compiler
+  # version HP92453-01 B.11.11.23709.GP, which incorrectly rejects
+  # declarations like `int a3[[(sizeof (unsigned char)) >= 0]];'.
+  # This bug is HP SR number 8606223364.
+  if test "$cross_compiling" = yes; then
+  # Depending upon the size, compute the lo and hi bounds.
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long long))) >= 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=0 ac_mid=0
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr $ac_mid + 1`
+		    if test $ac_lo -le $ac_mid; then
+		      ac_lo= ac_hi=
+		      break
+		    fi
+		    ac_mid=`expr 2 '*' $ac_mid + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long long))) < 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=-1 ac_mid=-1
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long long))) >= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_hi=`expr '(' $ac_mid ')' - 1`
+		       if test $ac_mid -le $ac_hi; then
+			 ac_lo= ac_hi=
+			 break
+		       fi
+		       ac_mid=`expr 2 '*' $ac_mid`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo= ac_hi=
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+# Binary search between lo and hi bounds.
+while test "x$ac_lo" != "x$ac_hi"; do
+  ac_mid=`expr '(' $ac_hi - $ac_lo ')' / 2 + $ac_lo`
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr '(' $ac_mid ')' + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+case $ac_lo in
+?*) ac_cv_sizeof_long_long=$ac_lo;;
+'') { { echo "$as_me:$LINENO: error: cannot compute sizeof (long long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; } ;;
+esac
+else
+  if test "$cross_compiling" = yes; then
+  { { echo "$as_me:$LINENO: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+long longval () { return (long) (sizeof (long long)); }
+unsigned long ulongval () { return (long) (sizeof (long long)); }
+#include <stdio.h>
+#include <stdlib.h>
+int
+main ()
+{
+
+  FILE *f = fopen ("conftest.val", "w");
+  if (! f)
+    exit (1);
+  if (((long) (sizeof (long long))) < 0)
+    {
+      long i = longval ();
+      if (i != ((long) (sizeof (long long))))
+	exit (1);
+      fprintf (f, "%ld\n", i);
+    }
+  else
+    {
+      unsigned long i = ulongval ();
+      if (i != ((long) (sizeof (long long))))
+	exit (1);
+      fprintf (f, "%lu\n", i);
+    }
+  exit (ferror (f) || fclose (f) != 0);
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_sizeof_long_long=`cat conftest.val`
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+{ { echo "$as_me:$LINENO: error: cannot compute sizeof (long long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+rm -f conftest.val
+else
+  ac_cv_sizeof_long_long=0
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_sizeof_long_long" >&5
+echo "${ECHO_T}$ac_cv_sizeof_long_long" >&6
+cat >>confdefs.h <<_ACEOF
+#define SIZEOF_LONG_LONG $ac_cv_sizeof_long_long
+_ACEOF
+
+
+echo "$as_me:$LINENO: checking for long" >&5
+echo $ECHO_N "checking for long... $ECHO_C" >&6
+if test "${ac_cv_type_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((long *) 0)
+  return 0;
+if (sizeof (long))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_long=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_long=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_long" >&5
+echo "${ECHO_T}$ac_cv_type_long" >&6
+
+echo "$as_me:$LINENO: checking size of long" >&5
+echo $ECHO_N "checking size of long... $ECHO_C" >&6
+if test "${ac_cv_sizeof_long+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test "$ac_cv_type_long" = yes; then
+  # The cast to unsigned long works around a bug in the HP C Compiler
+  # version HP92453-01 B.11.11.23709.GP, which incorrectly rejects
+  # declarations like `int a3[[(sizeof (unsigned char)) >= 0]];'.
+  # This bug is HP SR number 8606223364.
+  if test "$cross_compiling" = yes; then
+  # Depending upon the size, compute the lo and hi bounds.
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) >= 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=0 ac_mid=0
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr $ac_mid + 1`
+		    if test $ac_lo -le $ac_mid; then
+		      ac_lo= ac_hi=
+		      break
+		    fi
+		    ac_mid=`expr 2 '*' $ac_mid + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) < 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=-1 ac_mid=-1
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) >= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_hi=`expr '(' $ac_mid ')' - 1`
+		       if test $ac_mid -le $ac_hi; then
+			 ac_lo= ac_hi=
+			 break
+		       fi
+		       ac_mid=`expr 2 '*' $ac_mid`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo= ac_hi=
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+# Binary search between lo and hi bounds.
+while test "x$ac_lo" != "x$ac_hi"; do
+  ac_mid=`expr '(' $ac_hi - $ac_lo ')' / 2 + $ac_lo`
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (long))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr '(' $ac_mid ')' + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+case $ac_lo in
+?*) ac_cv_sizeof_long=$ac_lo;;
+'') { { echo "$as_me:$LINENO: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; } ;;
+esac
+else
+  if test "$cross_compiling" = yes; then
+  { { echo "$as_me:$LINENO: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+long longval () { return (long) (sizeof (long)); }
+unsigned long ulongval () { return (long) (sizeof (long)); }
+#include <stdio.h>
+#include <stdlib.h>
+int
+main ()
+{
+
+  FILE *f = fopen ("conftest.val", "w");
+  if (! f)
+    exit (1);
+  if (((long) (sizeof (long))) < 0)
+    {
+      long i = longval ();
+      if (i != ((long) (sizeof (long))))
+	exit (1);
+      fprintf (f, "%ld\n", i);
+    }
+  else
+    {
+      unsigned long i = ulongval ();
+      if (i != ((long) (sizeof (long))))
+	exit (1);
+      fprintf (f, "%lu\n", i);
+    }
+  exit (ferror (f) || fclose (f) != 0);
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_sizeof_long=`cat conftest.val`
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+{ { echo "$as_me:$LINENO: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (long), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+rm -f conftest.val
+else
+  ac_cv_sizeof_long=0
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_sizeof_long" >&5
+echo "${ECHO_T}$ac_cv_sizeof_long" >&6
+cat >>confdefs.h <<_ACEOF
+#define SIZEOF_LONG $ac_cv_sizeof_long
+_ACEOF
+
+
+echo "$as_me:$LINENO: checking for int" >&5
+echo $ECHO_N "checking for int... $ECHO_C" >&6
+if test "${ac_cv_type_int+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((int *) 0)
+  return 0;
+if (sizeof (int))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_int=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_int=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_int" >&5
+echo "${ECHO_T}$ac_cv_type_int" >&6
+
+echo "$as_me:$LINENO: checking size of int" >&5
+echo $ECHO_N "checking size of int... $ECHO_C" >&6
+if test "${ac_cv_sizeof_int+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test "$ac_cv_type_int" = yes; then
+  # The cast to unsigned long works around a bug in the HP C Compiler
+  # version HP92453-01 B.11.11.23709.GP, which incorrectly rejects
+  # declarations like `int a3[[(sizeof (unsigned char)) >= 0]];'.
+  # This bug is HP SR number 8606223364.
+  if test "$cross_compiling" = yes; then
+  # Depending upon the size, compute the lo and hi bounds.
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (int))) >= 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=0 ac_mid=0
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (int))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr $ac_mid + 1`
+		    if test $ac_lo -le $ac_mid; then
+		      ac_lo= ac_hi=
+		      break
+		    fi
+		    ac_mid=`expr 2 '*' $ac_mid + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (int))) < 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=-1 ac_mid=-1
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (int))) >= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_hi=`expr '(' $ac_mid ')' - 1`
+		       if test $ac_mid -le $ac_hi; then
+			 ac_lo= ac_hi=
+			 break
+		       fi
+		       ac_mid=`expr 2 '*' $ac_mid`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo= ac_hi=
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+# Binary search between lo and hi bounds.
+while test "x$ac_lo" != "x$ac_hi"; do
+  ac_mid=`expr '(' $ac_hi - $ac_lo ')' / 2 + $ac_lo`
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (int))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr '(' $ac_mid ')' + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+case $ac_lo in
+?*) ac_cv_sizeof_int=$ac_lo;;
+'') { { echo "$as_me:$LINENO: error: cannot compute sizeof (int), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (int), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; } ;;
+esac
+else
+  if test "$cross_compiling" = yes; then
+  { { echo "$as_me:$LINENO: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+long longval () { return (long) (sizeof (int)); }
+unsigned long ulongval () { return (long) (sizeof (int)); }
+#include <stdio.h>
+#include <stdlib.h>
+int
+main ()
+{
+
+  FILE *f = fopen ("conftest.val", "w");
+  if (! f)
+    exit (1);
+  if (((long) (sizeof (int))) < 0)
+    {
+      long i = longval ();
+      if (i != ((long) (sizeof (int))))
+	exit (1);
+      fprintf (f, "%ld\n", i);
+    }
+  else
+    {
+      unsigned long i = ulongval ();
+      if (i != ((long) (sizeof (int))))
+	exit (1);
+      fprintf (f, "%lu\n", i);
+    }
+  exit (ferror (f) || fclose (f) != 0);
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_sizeof_int=`cat conftest.val`
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+{ { echo "$as_me:$LINENO: error: cannot compute sizeof (int), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (int), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+rm -f conftest.val
+else
+  ac_cv_sizeof_int=0
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_sizeof_int" >&5
+echo "${ECHO_T}$ac_cv_sizeof_int" >&6
+cat >>confdefs.h <<_ACEOF
+#define SIZEOF_INT $ac_cv_sizeof_int
+_ACEOF
+
+
+echo "$as_me:$LINENO: checking for short" >&5
+echo $ECHO_N "checking for short... $ECHO_C" >&6
+if test "${ac_cv_type_short+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+if ((short *) 0)
+  return 0;
+if (sizeof (short))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_short=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_short=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_short" >&5
+echo "${ECHO_T}$ac_cv_type_short" >&6
+
+echo "$as_me:$LINENO: checking size of short" >&5
+echo $ECHO_N "checking size of short... $ECHO_C" >&6
+if test "${ac_cv_sizeof_short+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  if test "$ac_cv_type_short" = yes; then
+  # The cast to unsigned long works around a bug in the HP C Compiler
+  # version HP92453-01 B.11.11.23709.GP, which incorrectly rejects
+  # declarations like `int a3[[(sizeof (unsigned char)) >= 0]];'.
+  # This bug is HP SR number 8606223364.
+  if test "$cross_compiling" = yes; then
+  # Depending upon the size, compute the lo and hi bounds.
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (short))) >= 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=0 ac_mid=0
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (short))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr $ac_mid + 1`
+		    if test $ac_lo -le $ac_mid; then
+		      ac_lo= ac_hi=
+		      break
+		    fi
+		    ac_mid=`expr 2 '*' $ac_mid + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (short))) < 0)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=-1 ac_mid=-1
+  while :; do
+    cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (short))) >= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_lo=$ac_mid; break
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_hi=`expr '(' $ac_mid ')' - 1`
+		       if test $ac_mid -le $ac_hi; then
+			 ac_lo= ac_hi=
+			 break
+		       fi
+		       ac_mid=`expr 2 '*' $ac_mid`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+  done
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo= ac_hi=
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+# Binary search between lo and hi bounds.
+while test "x$ac_lo" != "x$ac_hi"; do
+  ac_mid=`expr '(' $ac_hi - $ac_lo ')' / 2 + $ac_lo`
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+int
+main ()
+{
+static int test_array [1 - 2 * !(((long) (sizeof (short))) <= $ac_mid)];
+test_array [0] = 0
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_hi=$ac_mid
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_lo=`expr '(' $ac_mid ')' + 1`
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+done
+case $ac_lo in
+?*) ac_cv_sizeof_short=$ac_lo;;
+'') { { echo "$as_me:$LINENO: error: cannot compute sizeof (short), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (short), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; } ;;
+esac
+else
+  if test "$cross_compiling" = yes; then
+  { { echo "$as_me:$LINENO: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot run test program while cross compiling
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+$ac_includes_default
+long longval () { return (long) (sizeof (short)); }
+unsigned long ulongval () { return (long) (sizeof (short)); }
+#include <stdio.h>
+#include <stdlib.h>
+int
+main ()
+{
+
+  FILE *f = fopen ("conftest.val", "w");
+  if (! f)
+    exit (1);
+  if (((long) (sizeof (short))) < 0)
+    {
+      long i = longval ();
+      if (i != ((long) (sizeof (short))))
+	exit (1);
+      fprintf (f, "%ld\n", i);
+    }
+  else
+    {
+      unsigned long i = ulongval ();
+      if (i != ((long) (sizeof (short))))
+	exit (1);
+      fprintf (f, "%lu\n", i);
+    }
+  exit (ferror (f) || fclose (f) != 0);
+
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest$ac_exeext
+if { (eval echo "$as_me:$LINENO: \"$ac_link\"") >&5
+  (eval $ac_link) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } && { ac_try='./conftest$ac_exeext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_sizeof_short=`cat conftest.val`
+else
+  echo "$as_me: program exited with status $ac_status" >&5
+echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+( exit $ac_status )
+{ { echo "$as_me:$LINENO: error: cannot compute sizeof (short), 77
+See \`config.log' for more details." >&5
+echo "$as_me: error: cannot compute sizeof (short), 77
+See \`config.log' for more details." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+rm -f core *.core gmon.out bb.out conftest$ac_exeext conftest.$ac_objext conftest.$ac_ext
+fi
+fi
+rm -f conftest.val
+else
+  ac_cv_sizeof_short=0
+fi
+fi
+echo "$as_me:$LINENO: result: $ac_cv_sizeof_short" >&5
+echo "${ECHO_T}$ac_cv_sizeof_short" >&6
+cat >>confdefs.h <<_ACEOF
+#define SIZEOF_SHORT $ac_cv_sizeof_short
+_ACEOF
+
+
+echo "$as_me:$LINENO: checking for struct in6_addr" >&5
+echo $ECHO_N "checking for struct in6_addr... $ECHO_C" >&6
+if test "${ac_cv_type_struct_in6_addr+set}" = set; then
+  echo $ECHO_N "(cached) $ECHO_C" >&6
+else
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+#ifdef WIN32
+#include <winsock2.h>
+#else
+#include <sys/types.h>
+#include <netinet/in.h>
+#include <sys/socket.h>
+#endif
+#ifdef HAVE_NETINET_IN6_H
+#include <netinet/in6.h>
+#endif
+
+int
+main ()
+{
+if ((struct in6_addr *) 0)
+  return 0;
+if (sizeof (struct in6_addr))
+  return 0;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  ac_cv_type_struct_in6_addr=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+ac_cv_type_struct_in6_addr=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+echo "$as_me:$LINENO: result: $ac_cv_type_struct_in6_addr" >&5
+echo "${ECHO_T}$ac_cv_type_struct_in6_addr" >&6
+if test $ac_cv_type_struct_in6_addr = yes; then
+
+cat >>confdefs.h <<_ACEOF
+#define HAVE_STRUCT_IN6_ADDR 1
+_ACEOF
+
+
+fi
+
+
+echo "$as_me:$LINENO: checking for socklen_t" >&5
+echo $ECHO_N "checking for socklen_t... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+ #include <sys/types.h>
+ #include <sys/socket.h>
+int
+main ()
+{
+socklen_t x;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define socklen_t unsigned int
+_ACEOF
+
+
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+echo "$as_me:$LINENO: checking whether our compiler supports __func__" >&5
+echo $ECHO_N "checking whether our compiler supports __func__... $ECHO_C" >&6
+cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+ const char *cp = __func__;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+ echo "$as_me:$LINENO: checking whether our compiler supports __FUNCTION__" >&5
+echo $ECHO_N "checking whether our compiler supports __FUNCTION__... $ECHO_C" >&6
+ cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+ const char *cp = __FUNCTION__;
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  echo "$as_me:$LINENO: result: yes" >&5
+echo "${ECHO_T}yes" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define __func__ __FUNCTION__
+_ACEOF
+
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+echo "$as_me:$LINENO: result: no" >&5
+echo "${ECHO_T}no" >&6
+
+cat >>confdefs.h <<\_ACEOF
+#define __func__ __FILE__
+_ACEOF
+
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+
+# Add some more warnings which we use in development but not in the
+# released versions.  (Some relevant gcc versions can't handle these.)
+if test x$enable_gcc_warnings = xyes; then
+
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+#if !defined(__GNUC__) || (__GNUC__ < 4)
+#error
+#endif
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  have_gcc4=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+have_gcc4=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+  cat >conftest.$ac_ext <<_ACEOF
+/* confdefs.h.  */
+_ACEOF
+cat confdefs.h >>conftest.$ac_ext
+cat >>conftest.$ac_ext <<_ACEOF
+/* end confdefs.h.  */
+
+int
+main ()
+{
+
+#if !defined(__GNUC__) || (__GNUC__ < 4) || (__GNUC__ == 4 && __GNUC_MINOR__ < 2)
+#error
+#endif
+  ;
+  return 0;
+}
+_ACEOF
+rm -f conftest.$ac_objext
+if { (eval echo "$as_me:$LINENO: \"$ac_compile\"") >&5
+  (eval $ac_compile) 2>conftest.er1
+  ac_status=$?
+  grep -v '^ *+' conftest.er1 >conftest.err
+  rm -f conftest.er1
+  cat conftest.err >&5
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); } &&
+	 { ac_try='test -z "$ac_c_werror_flag"
+			 || test ! -s conftest.err'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; } &&
+	 { ac_try='test -s conftest.$ac_objext'
+  { (eval echo "$as_me:$LINENO: \"$ac_try\"") >&5
+  (eval $ac_try) 2>&5
+  ac_status=$?
+  echo "$as_me:$LINENO: \$? = $ac_status" >&5
+  (exit $ac_status); }; }; then
+  have_gcc42=yes
+else
+  echo "$as_me: failed program was:" >&5
+sed 's/^/| /' conftest.$ac_ext >&5
+
+have_gcc42=no
+fi
+rm -f conftest.err conftest.$ac_objext conftest.$ac_ext
+
+  CFLAGS="$CFLAGS -W -Wfloat-equal -Wundef -Wpointer-arith -Wstrict-prototypes -Wmissing-prototypes -Wwrite-strings -Wredundant-decls -Wchar-subscripts -Wcomment -Wformat=2 -Wwrite-strings -Wmissing-declarations -Wredundant-decls -Wnested-externs -Wbad-function-cast -Wswitch-enum -Werror"
+  CFLAGS="$CFLAGS -Wno-unused-parameter -Wno-sign-compare -Wstrict-aliasing"
+
+  if test x$have_gcc4 = xyes ; then
+    # These warnings break gcc 3.3.5 and work on gcc 4.0.2
+    CFLAGS="$CFLAGS -Winit-self -Wmissing-field-initializers -Wdeclaration-after-statement"
+    #CFLAGS="$CFLAGS -Wold-style-definition"
+  fi
+
+  if test x$have_gcc42 = xyes ; then
+    # These warnings break gcc 4.0.2 and work on gcc 4.2
+    CFLAGS="$CFLAGS -Waddress -Wnormalized=id -Woverride-init"
+  fi
+
+##This will break the world on some 64-bit architectures
+# CFLAGS="$CFLAGS -Winline"
+
+fi
+
+          ac_config_files="$ac_config_files Makefile"
+cat >confcache <<\_ACEOF
+# This file is a shell script that caches the results of configure
+# tests run on this system so they can be shared between configure
+# scripts and configure runs, see configure's option --config-cache.
+# It is not useful on other systems.  If it contains results you don't
+# want to keep, you may remove or edit it.
+#
+# config.status only pays attention to the cache file if you give it
+# the --recheck option to rerun configure.
+#
+# `ac_cv_env_foo' variables (set or unset) will be overridden when
+# loading this file, other *unset* `ac_cv_foo' will be assigned the
+# following values.
+
+_ACEOF
+
+# The following way of writing the cache mishandles newlines in values,
+# but we know of no workaround that is simple, portable, and efficient.
+# So, don't put newlines in cache variables' values.
+# Ultrix sh set writes to stderr and can't be redirected directly,
+# and sets the high bit in the cache file unless we assign to the vars.
+{
+  (set) 2>&1 |
+    case `(ac_space=' '; set | grep ac_space) 2>&1` in
+    *ac_space=\ *)
+      # `set' does not quote correctly, so add quotes (double-quote
+      # substitution turns \\\\ into \\, and sed turns \\ into \).
+      sed -n \
+	"s/'/'\\\\''/g;
+	  s/^\\([_$as_cr_alnum]*_cv_[_$as_cr_alnum]*\\)=\\(.*\\)/\\1='\\2'/p"
+      ;;
+    *)
+      # `set' quotes correctly as required by POSIX, so do not add quotes.
+      sed -n \
+	"s/^\\([_$as_cr_alnum]*_cv_[_$as_cr_alnum]*\\)=\\(.*\\)/\\1=\\2/p"
+      ;;
+    esac;
+} |
+  sed '
+     t clear
+     : clear
+     s/^\([^=]*\)=\(.*[{}].*\)$/test "${\1+set}" = set || &/
+     t end
+     /^ac_cv_env/!s/^\([^=]*\)=\(.*\)$/\1=${\1=\2}/
+     : end' >>confcache
+if diff $cache_file confcache >/dev/null 2>&1; then :; else
+  if test -w $cache_file; then
+    test "x$cache_file" != "x/dev/null" && echo "updating cache $cache_file"
+    cat confcache >$cache_file
+  else
+    echo "not updating unwritable cache $cache_file"
+  fi
+fi
+rm -f confcache
+
+test "x$prefix" = xNONE && prefix=$ac_default_prefix
+# Let make expand exec_prefix.
+test "x$exec_prefix" = xNONE && exec_prefix='${prefix}'
+
+# VPATH may cause trouble with some makes, so we remove $(srcdir),
+# ${srcdir} and @srcdir@ from VPATH if srcdir is ".", strip leading and
+# trailing colons and then remove the whole line if VPATH becomes empty
+# (actually we leave an empty line to preserve line numbers).
+if test "x$srcdir" = x.; then
+  ac_vpsub='/^[	 ]*VPATH[	 ]*=/{
+s/:*\$(srcdir):*/:/;
+s/:*\${srcdir}:*/:/;
+s/:*@srcdir@:*/:/;
+s/^\([^=]*=[	 ]*\):*/\1/;
+s/:*$//;
+s/^[^=]*=[	 ]*$//;
+}'
+fi
+
+DEFS=-DHAVE_CONFIG_H
+
+ac_libobjs=
+ac_ltlibobjs=
+for ac_i in : $LIBOBJS; do test "x$ac_i" = x: && continue
+  # 1. Remove the extension, and $U if already installed.
+  ac_i=`echo "$ac_i" |
+	 sed 's/\$U\././;s/\.o$//;s/\.obj$//'`
+  # 2. Add them.
+  ac_libobjs="$ac_libobjs $ac_i\$U.$ac_objext"
+  ac_ltlibobjs="$ac_ltlibobjs $ac_i"'$U.lo'
+done
+LIBOBJS=$ac_libobjs
+
+LTLIBOBJS=$ac_ltlibobjs
+
+
+if test -z "${AMDEP_TRUE}" && test -z "${AMDEP_FALSE}"; then
+  { { echo "$as_me:$LINENO: error: conditional \"AMDEP\" was never defined.
+Usually this means the macro was only invoked conditionally." >&5
+echo "$as_me: error: conditional \"AMDEP\" was never defined.
+Usually this means the macro was only invoked conditionally." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+if test -z "${am__fastdepCC_TRUE}" && test -z "${am__fastdepCC_FALSE}"; then
+  { { echo "$as_me:$LINENO: error: conditional \"am__fastdepCC\" was never defined.
+Usually this means the macro was only invoked conditionally." >&5
+echo "$as_me: error: conditional \"am__fastdepCC\" was never defined.
+Usually this means the macro was only invoked conditionally." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+if test -z "${BUILD_WIN32_TRUE}" && test -z "${BUILD_WIN32_FALSE}"; then
+  { { echo "$as_me:$LINENO: error: conditional \"BUILD_WIN32\" was never defined.
+Usually this means the macro was only invoked conditionally." >&5
+echo "$as_me: error: conditional \"BUILD_WIN32\" was never defined.
+Usually this means the macro was only invoked conditionally." >&2;}
+   { (exit 1); exit 1; }; }
+fi
+
+: ${CONFIG_STATUS=./config.status}
+ac_clean_files_save=$ac_clean_files
+ac_clean_files="$ac_clean_files $CONFIG_STATUS"
+{ echo "$as_me:$LINENO: creating $CONFIG_STATUS" >&5
+echo "$as_me: creating $CONFIG_STATUS" >&6;}
+cat >$CONFIG_STATUS <<_ACEOF
+#! $SHELL
+# Generated by $as_me.
+# Run this file to recreate the current configuration.
+# Compiler output produced by configure, useful for debugging
+# configure, is in config.log if it exists.
+
+debug=false
+ac_cs_recheck=false
+ac_cs_silent=false
+SHELL=\${CONFIG_SHELL-$SHELL}
+_ACEOF
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+## --------------------- ##
+## M4sh Initialization.  ##
+## --------------------- ##
+
+# Be Bourne compatible
+if test -n "${ZSH_VERSION+set}" && (emulate sh) >/dev/null 2>&1; then
+  emulate sh
+  NULLCMD=:
+  # Zsh 3.x and 4.x performs word splitting on ${1+"$@"}, which
+  # is contrary to our usage.  Disable this feature.
+  alias -g '${1+"$@"}'='"$@"'
+elif test -n "${BASH_VERSION+set}" && (set -o posix) >/dev/null 2>&1; then
+  set -o posix
+fi
+DUALCASE=1; export DUALCASE # for MKS sh
+
+# Support unset when possible.
+if ( (MAIL=60; unset MAIL) || exit) >/dev/null 2>&1; then
+  as_unset=unset
+else
+  as_unset=false
+fi
+
+
+# Work around bugs in pre-3.0 UWIN ksh.
+$as_unset ENV MAIL MAILPATH
+PS1='$ '
+PS2='> '
+PS4='+ '
+
+# NLS nuisances.
+for as_var in \
+  LANG LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION \
+  LC_MEASUREMENT LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER \
+  LC_TELEPHONE LC_TIME
+do
+  if (set +x; test -z "`(eval $as_var=C; export $as_var) 2>&1`"); then
+    eval $as_var=C; export $as_var
+  else
+    $as_unset $as_var
+  fi
+done
+
+# Required to use basename.
+if expr a : '\(a\)' >/dev/null 2>&1; then
+  as_expr=expr
+else
+  as_expr=false
+fi
+
+if (basename /) >/dev/null 2>&1 && test "X`basename / 2>&1`" = "X/"; then
+  as_basename=basename
+else
+  as_basename=false
+fi
+
+
+# Name of the executable.
+as_me=`$as_basename "$0" ||
+$as_expr X/"$0" : '.*/\([^/][^/]*\)/*$' \| \
+	 X"$0" : 'X\(//\)$' \| \
+	 X"$0" : 'X\(/\)$' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X/"$0" |
+    sed '/^.*\/\([^/][^/]*\)\/*$/{ s//\1/; q; }
+  	  /^X\/\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\/\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+
+
+# PATH needs CR, and LINENO needs CR and PATH.
+# Avoid depending upon Character Ranges.
+as_cr_letters='abcdefghijklmnopqrstuvwxyz'
+as_cr_LETTERS='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
+as_cr_Letters=$as_cr_letters$as_cr_LETTERS
+as_cr_digits='0123456789'
+as_cr_alnum=$as_cr_Letters$as_cr_digits
+
+# The user is always right.
+if test "${PATH_SEPARATOR+set}" != set; then
+  echo "#! /bin/sh" >conf$$.sh
+  echo  "exit 0"   >>conf$$.sh
+  chmod +x conf$$.sh
+  if (PATH="/nonexistent;."; conf$$.sh) >/dev/null 2>&1; then
+    PATH_SEPARATOR=';'
+  else
+    PATH_SEPARATOR=:
+  fi
+  rm -f conf$$.sh
+fi
+
+
+  as_lineno_1=$LINENO
+  as_lineno_2=$LINENO
+  as_lineno_3=`(expr $as_lineno_1 + 1) 2>/dev/null`
+  test "x$as_lineno_1" != "x$as_lineno_2" &&
+  test "x$as_lineno_3"  = "x$as_lineno_2"  || {
+  # Find who we are.  Look in the path if we contain no path at all
+  # relative or not.
+  case $0 in
+    *[\\/]* ) as_myself=$0 ;;
+    *) as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in $PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  test -r "$as_dir/$0" && as_myself=$as_dir/$0 && break
+done
+
+       ;;
+  esac
+  # We did not find ourselves, most probably we were run as `sh COMMAND'
+  # in which case we are not to be found in the path.
+  if test "x$as_myself" = x; then
+    as_myself=$0
+  fi
+  if test ! -f "$as_myself"; then
+    { { echo "$as_me:$LINENO: error: cannot find myself; rerun with an absolute path" >&5
+echo "$as_me: error: cannot find myself; rerun with an absolute path" >&2;}
+   { (exit 1); exit 1; }; }
+  fi
+  case $CONFIG_SHELL in
+  '')
+    as_save_IFS=$IFS; IFS=$PATH_SEPARATOR
+for as_dir in /bin$PATH_SEPARATOR/usr/bin$PATH_SEPARATOR$PATH
+do
+  IFS=$as_save_IFS
+  test -z "$as_dir" && as_dir=.
+  for as_base in sh bash ksh sh5; do
+	 case $as_dir in
+	 /*)
+	   if ("$as_dir/$as_base" -c '
+  as_lineno_1=$LINENO
+  as_lineno_2=$LINENO
+  as_lineno_3=`(expr $as_lineno_1 + 1) 2>/dev/null`
+  test "x$as_lineno_1" != "x$as_lineno_2" &&
+  test "x$as_lineno_3"  = "x$as_lineno_2" ') 2>/dev/null; then
+	     $as_unset BASH_ENV || test "${BASH_ENV+set}" != set || { BASH_ENV=; export BASH_ENV; }
+	     $as_unset ENV || test "${ENV+set}" != set || { ENV=; export ENV; }
+	     CONFIG_SHELL=$as_dir/$as_base
+	     export CONFIG_SHELL
+	     exec "$CONFIG_SHELL" "$0" ${1+"$@"}
+	   fi;;
+	 esac
+       done
+done
+;;
+  esac
+
+  # Create $as_me.lineno as a copy of $as_myself, but with $LINENO
+  # uniformly replaced by the line number.  The first 'sed' inserts a
+  # line-number line before each line; the second 'sed' does the real
+  # work.  The second script uses 'N' to pair each line-number line
+  # with the numbered line, and appends trailing '-' during
+  # substitution so that $LINENO is not a special case at line end.
+  # (Raja R Harinath suggested sed '=', and Paul Eggert wrote the
+  # second 'sed' script.  Blame Lee E. McMahon for sed's syntax.  :-)
+  sed '=' <$as_myself |
+    sed '
+      N
+      s,$,-,
+      : loop
+      s,^\(['$as_cr_digits']*\)\(.*\)[$]LINENO\([^'$as_cr_alnum'_]\),\1\2\1\3,
+      t loop
+      s,-$,,
+      s,^['$as_cr_digits']*\n,,
+    ' >$as_me.lineno &&
+  chmod +x $as_me.lineno ||
+    { { echo "$as_me:$LINENO: error: cannot create $as_me.lineno; rerun with a POSIX shell" >&5
+echo "$as_me: error: cannot create $as_me.lineno; rerun with a POSIX shell" >&2;}
+   { (exit 1); exit 1; }; }
+
+  # Don't try to exec as it changes $[0], causing all sort of problems
+  # (the dirname of $[0] is not the place where we might find the
+  # original and so on.  Autoconf is especially sensible to this).
+  . ./$as_me.lineno
+  # Exit status is that of the last command.
+  exit
+}
+
+
+case `echo "testing\c"; echo 1,2,3`,`echo -n testing; echo 1,2,3` in
+  *c*,-n*) ECHO_N= ECHO_C='
+' ECHO_T='	' ;;
+  *c*,*  ) ECHO_N=-n ECHO_C= ECHO_T= ;;
+  *)       ECHO_N= ECHO_C='\c' ECHO_T= ;;
+esac
+
+if expr a : '\(a\)' >/dev/null 2>&1; then
+  as_expr=expr
+else
+  as_expr=false
+fi
+
+rm -f conf$$ conf$$.exe conf$$.file
+echo >conf$$.file
+if ln -s conf$$.file conf$$ 2>/dev/null; then
+  # We could just check for DJGPP; but this test a) works b) is more generic
+  # and c) will remain valid once DJGPP supports symlinks (DJGPP 2.04).
+  if test -f conf$$.exe; then
+    # Don't use ln at all; we don't have any links
+    as_ln_s='cp -p'
+  else
+    as_ln_s='ln -s'
+  fi
+elif ln conf$$.file conf$$ 2>/dev/null; then
+  as_ln_s=ln
+else
+  as_ln_s='cp -p'
+fi
+rm -f conf$$ conf$$.exe conf$$.file
+
+if mkdir -p . 2>/dev/null; then
+  as_mkdir_p=:
+else
+  test -d ./-p && rmdir ./-p
+  as_mkdir_p=false
+fi
+
+as_executable_p="test -f"
+
+# Sed expression to map a string onto a valid CPP name.
+as_tr_cpp="eval sed 'y%*$as_cr_letters%P$as_cr_LETTERS%;s%[^_$as_cr_alnum]%_%g'"
+
+# Sed expression to map a string onto a valid variable name.
+as_tr_sh="eval sed 'y%*+%pp%;s%[^_$as_cr_alnum]%_%g'"
+
+
+# IFS
+# We need space, tab and new line, in precisely that order.
+as_nl='
+'
+IFS=" 	$as_nl"
+
+# CDPATH.
+$as_unset CDPATH
+
+exec 6>&1
+
+# Open the log real soon, to keep \$[0] and so on meaningful, and to
+# report actual input values of CONFIG_FILES etc. instead of their
+# values after options handling.  Logging --version etc. is OK.
+exec 5>>config.log
+{
+  echo
+  sed 'h;s/./-/g;s/^.../## /;s/...$/ ##/;p;x;p;x' <<_ASBOX
+## Running $as_me. ##
+_ASBOX
+} >&5
+cat >&5 <<_CSEOF
+
+This file was extended by $as_me, which was
+generated by GNU Autoconf 2.59.  Invocation command line was
+
+  CONFIG_FILES    = $CONFIG_FILES
+  CONFIG_HEADERS  = $CONFIG_HEADERS
+  CONFIG_LINKS    = $CONFIG_LINKS
+  CONFIG_COMMANDS = $CONFIG_COMMANDS
+  $ $0 $@
+
+_CSEOF
+echo "on `(hostname || uname -n) 2>/dev/null | sed 1q`" >&5
+echo >&5
+_ACEOF
+
+# Files that config.status was made for.
+if test -n "$ac_config_files"; then
+  echo "config_files=\"$ac_config_files\"" >>$CONFIG_STATUS
+fi
+
+if test -n "$ac_config_headers"; then
+  echo "config_headers=\"$ac_config_headers\"" >>$CONFIG_STATUS
+fi
+
+if test -n "$ac_config_links"; then
+  echo "config_links=\"$ac_config_links\"" >>$CONFIG_STATUS
+fi
+
+if test -n "$ac_config_commands"; then
+  echo "config_commands=\"$ac_config_commands\"" >>$CONFIG_STATUS
+fi
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+
+ac_cs_usage="\
+\`$as_me' instantiates files from templates according to the
+current configuration.
+
+Usage: $0 [OPTIONS] [FILE]...
+
+  -h, --help       print this help, then exit
+  -V, --version    print version number, then exit
+  -q, --quiet      do not print progress messages
+  -d, --debug      don't remove temporary files
+      --recheck    update $as_me by reconfiguring in the same conditions
+  --file=FILE[:TEMPLATE]
+		   instantiate the configuration file FILE
+  --header=FILE[:TEMPLATE]
+		   instantiate the configuration header FILE
+
+Configuration files:
+$config_files
+
+Configuration headers:
+$config_headers
+
+Configuration commands:
+$config_commands
+
+Report bugs to <bug-autoconf@gnu.org>."
+_ACEOF
+
+cat >>$CONFIG_STATUS <<_ACEOF
+ac_cs_version="\\
+config.status
+configured by $0, generated by GNU Autoconf 2.59,
+  with options \\"`echo "$ac_configure_args" | sed 's/[\\""\`\$]/\\\\&/g'`\\"
+
+Copyright (C) 2003 Free Software Foundation, Inc.
+This config.status script is free software; the Free Software Foundation
+gives unlimited permission to copy, distribute and modify it."
+srcdir=$srcdir
+INSTALL="$INSTALL"
+_ACEOF
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+# If no file are specified by the user, then we need to provide default
+# value.  By we need to know if files were specified by the user.
+ac_need_defaults=:
+while test $# != 0
+do
+  case $1 in
+  --*=*)
+    ac_option=`expr "x$1" : 'x\([^=]*\)='`
+    ac_optarg=`expr "x$1" : 'x[^=]*=\(.*\)'`
+    ac_shift=:
+    ;;
+  -*)
+    ac_option=$1
+    ac_optarg=$2
+    ac_shift=shift
+    ;;
+  *) # This is not an option, so the user has probably given explicit
+     # arguments.
+     ac_option=$1
+     ac_need_defaults=false;;
+  esac
+
+  case $ac_option in
+  # Handling of the options.
+_ACEOF
+cat >>$CONFIG_STATUS <<\_ACEOF
+  -recheck | --recheck | --rechec | --reche | --rech | --rec | --re | --r)
+    ac_cs_recheck=: ;;
+  --version | --vers* | -V )
+    echo "$ac_cs_version"; exit 0 ;;
+  --he | --h)
+    # Conflict between --help and --header
+    { { echo "$as_me:$LINENO: error: ambiguous option: $1
+Try \`$0 --help' for more information." >&5
+echo "$as_me: error: ambiguous option: $1
+Try \`$0 --help' for more information." >&2;}
+   { (exit 1); exit 1; }; };;
+  --help | --hel | -h )
+    echo "$ac_cs_usage"; exit 0 ;;
+  --debug | --d* | -d )
+    debug=: ;;
+  --file | --fil | --fi | --f )
+    $ac_shift
+    CONFIG_FILES="$CONFIG_FILES $ac_optarg"
+    ac_need_defaults=false;;
+  --header | --heade | --head | --hea )
+    $ac_shift
+    CONFIG_HEADERS="$CONFIG_HEADERS $ac_optarg"
+    ac_need_defaults=false;;
+  -q | -quiet | --quiet | --quie | --qui | --qu | --q \
+  | -silent | --silent | --silen | --sile | --sil | --si | --s)
+    ac_cs_silent=: ;;
+
+  # This is an error.
+  -*) { { echo "$as_me:$LINENO: error: unrecognized option: $1
+Try \`$0 --help' for more information." >&5
+echo "$as_me: error: unrecognized option: $1
+Try \`$0 --help' for more information." >&2;}
+   { (exit 1); exit 1; }; } ;;
+
+  *) ac_config_targets="$ac_config_targets $1" ;;
+
+  esac
+  shift
+done
+
+ac_configure_extra_args=
+
+if $ac_cs_silent; then
+  exec 6>/dev/null
+  ac_configure_extra_args="$ac_configure_extra_args --silent"
+fi
+
+_ACEOF
+cat >>$CONFIG_STATUS <<_ACEOF
+if \$ac_cs_recheck; then
+  echo "running $SHELL $0 " $ac_configure_args \$ac_configure_extra_args " --no-create --no-recursion" >&6
+  exec $SHELL $0 $ac_configure_args \$ac_configure_extra_args --no-create --no-recursion
+fi
+
+_ACEOF
+
+cat >>$CONFIG_STATUS <<_ACEOF
+#
+# INIT-COMMANDS section.
+#
+
+AMDEP_TRUE="$AMDEP_TRUE" ac_aux_dir="$ac_aux_dir"
+
+_ACEOF
+
+
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+for ac_config_target in $ac_config_targets
+do
+  case "$ac_config_target" in
+  # Handling of arguments.
+  "Makefile" ) CONFIG_FILES="$CONFIG_FILES Makefile" ;;
+  "depfiles" ) CONFIG_COMMANDS="$CONFIG_COMMANDS depfiles" ;;
+  "config.h" ) CONFIG_HEADERS="$CONFIG_HEADERS config.h" ;;
+  *) { { echo "$as_me:$LINENO: error: invalid argument: $ac_config_target" >&5
+echo "$as_me: error: invalid argument: $ac_config_target" >&2;}
+   { (exit 1); exit 1; }; };;
+  esac
+done
+
+# If the user did not use the arguments to specify the items to instantiate,
+# then the envvar interface is used.  Set only those that are not.
+# We use the long form for the default assignment because of an extremely
+# bizarre bug on SunOS 4.1.3.
+if $ac_need_defaults; then
+  test "${CONFIG_FILES+set}" = set || CONFIG_FILES=$config_files
+  test "${CONFIG_HEADERS+set}" = set || CONFIG_HEADERS=$config_headers
+  test "${CONFIG_COMMANDS+set}" = set || CONFIG_COMMANDS=$config_commands
+fi
+
+# Have a temporary directory for convenience.  Make it in the build tree
+# simply because there is no reason to put it here, and in addition,
+# creating and moving files from /tmp can sometimes cause problems.
+# Create a temporary directory, and hook for its removal unless debugging.
+$debug ||
+{
+  trap 'exit_status=$?; rm -rf $tmp && exit $exit_status' 0
+  trap '{ (exit 1); exit 1; }' 1 2 13 15
+}
+
+# Create a (secure) tmp directory for tmp files.
+
+{
+  tmp=`(umask 077 && mktemp -d -q "./confstatXXXXXX") 2>/dev/null` &&
+  test -n "$tmp" && test -d "$tmp"
+}  ||
+{
+  tmp=./confstat$$-$RANDOM
+  (umask 077 && mkdir $tmp)
+} ||
+{
+   echo "$me: cannot create a temporary directory in ." >&2
+   { (exit 1); exit 1; }
+}
+
+_ACEOF
+
+cat >>$CONFIG_STATUS <<_ACEOF
+
+#
+# CONFIG_FILES section.
+#
+
+# No need to generate the scripts if there are no CONFIG_FILES.
+# This happens for instance when ./config.status config.h
+if test -n "\$CONFIG_FILES"; then
+  # Protect against being on the right side of a sed subst in config.status.
+  sed 's/,@/@@/; s/@,/@@/; s/,;t t\$/@;t t/; /@;t t\$/s/[\\\\&,]/\\\\&/g;
+   s/@@/,@/; s/@@/@,/; s/@;t t\$/,;t t/' >\$tmp/subs.sed <<\\CEOF
+s,@SHELL@,$SHELL,;t t
+s,@PATH_SEPARATOR@,$PATH_SEPARATOR,;t t
+s,@PACKAGE_NAME@,$PACKAGE_NAME,;t t
+s,@PACKAGE_TARNAME@,$PACKAGE_TARNAME,;t t
+s,@PACKAGE_VERSION@,$PACKAGE_VERSION,;t t
+s,@PACKAGE_STRING@,$PACKAGE_STRING,;t t
+s,@PACKAGE_BUGREPORT@,$PACKAGE_BUGREPORT,;t t
+s,@exec_prefix@,$exec_prefix,;t t
+s,@prefix@,$prefix,;t t
+s,@program_transform_name@,$program_transform_name,;t t
+s,@bindir@,$bindir,;t t
+s,@sbindir@,$sbindir,;t t
+s,@libexecdir@,$libexecdir,;t t
+s,@datadir@,$datadir,;t t
+s,@sysconfdir@,$sysconfdir,;t t
+s,@sharedstatedir@,$sharedstatedir,;t t
+s,@localstatedir@,$localstatedir,;t t
+s,@libdir@,$libdir,;t t
+s,@includedir@,$includedir,;t t
+s,@oldincludedir@,$oldincludedir,;t t
+s,@infodir@,$infodir,;t t
+s,@mandir@,$mandir,;t t
+s,@build_alias@,$build_alias,;t t
+s,@host_alias@,$host_alias,;t t
+s,@target_alias@,$target_alias,;t t
+s,@DEFS@,$DEFS,;t t
+s,@ECHO_C@,$ECHO_C,;t t
+s,@ECHO_N@,$ECHO_N,;t t
+s,@ECHO_T@,$ECHO_T,;t t
+s,@LIBS@,$LIBS,;t t
+s,@INSTALL_PROGRAM@,$INSTALL_PROGRAM,;t t
+s,@INSTALL_SCRIPT@,$INSTALL_SCRIPT,;t t
+s,@INSTALL_DATA@,$INSTALL_DATA,;t t
+s,@CYGPATH_W@,$CYGPATH_W,;t t
+s,@PACKAGE@,$PACKAGE,;t t
+s,@VERSION@,$VERSION,;t t
+s,@ACLOCAL@,$ACLOCAL,;t t
+s,@AUTOCONF@,$AUTOCONF,;t t
+s,@AUTOMAKE@,$AUTOMAKE,;t t
+s,@AUTOHEADER@,$AUTOHEADER,;t t
+s,@MAKEINFO@,$MAKEINFO,;t t
+s,@install_sh@,$install_sh,;t t
+s,@STRIP@,$STRIP,;t t
+s,@ac_ct_STRIP@,$ac_ct_STRIP,;t t
+s,@INSTALL_STRIP_PROGRAM@,$INSTALL_STRIP_PROGRAM,;t t
+s,@mkdir_p@,$mkdir_p,;t t
+s,@AWK@,$AWK,;t t
+s,@SET_MAKE@,$SET_MAKE,;t t
+s,@am__leading_dot@,$am__leading_dot,;t t
+s,@AMTAR@,$AMTAR,;t t
+s,@am__tar@,$am__tar,;t t
+s,@am__untar@,$am__untar,;t t
+s,@CC@,$CC,;t t
+s,@CFLAGS@,$CFLAGS,;t t
+s,@LDFLAGS@,$LDFLAGS,;t t
+s,@CPPFLAGS@,$CPPFLAGS,;t t
+s,@ac_ct_CC@,$ac_ct_CC,;t t
+s,@EXEEXT@,$EXEEXT,;t t
+s,@OBJEXT@,$OBJEXT,;t t
+s,@DEPDIR@,$DEPDIR,;t t
+s,@am__include@,$am__include,;t t
+s,@am__quote@,$am__quote,;t t
+s,@AMDEP_TRUE@,$AMDEP_TRUE,;t t
+s,@AMDEP_FALSE@,$AMDEP_FALSE,;t t
+s,@AMDEPBACKSLASH@,$AMDEPBACKSLASH,;t t
+s,@CCDEPMODE@,$CCDEPMODE,;t t
+s,@am__fastdepCC_TRUE@,$am__fastdepCC_TRUE,;t t
+s,@am__fastdepCC_FALSE@,$am__fastdepCC_FALSE,;t t
+s,@LN_S@,$LN_S,;t t
+s,@CPP@,$CPP,;t t
+s,@EGREP@,$EGREP,;t t
+s,@RANLIB@,$RANLIB,;t t
+s,@ac_ct_RANLIB@,$ac_ct_RANLIB,;t t
+s,@BUILD_WIN32_TRUE@,$BUILD_WIN32_TRUE,;t t
+s,@BUILD_WIN32_FALSE@,$BUILD_WIN32_FALSE,;t t
+s,@LIBOBJS@,$LIBOBJS,;t t
+s,@LTLIBOBJS@,$LTLIBOBJS,;t t
+CEOF
+
+_ACEOF
+
+  cat >>$CONFIG_STATUS <<\_ACEOF
+  # Split the substitutions into bite-sized pieces for seds with
+  # small command number limits, like on Digital OSF/1 and HP-UX.
+  ac_max_sed_lines=48
+  ac_sed_frag=1 # Number of current file.
+  ac_beg=1 # First line for current file.
+  ac_end=$ac_max_sed_lines # Line after last line for current file.
+  ac_more_lines=:
+  ac_sed_cmds=
+  while $ac_more_lines; do
+    if test $ac_beg -gt 1; then
+      sed "1,${ac_beg}d; ${ac_end}q" $tmp/subs.sed >$tmp/subs.frag
+    else
+      sed "${ac_end}q" $tmp/subs.sed >$tmp/subs.frag
+    fi
+    if test ! -s $tmp/subs.frag; then
+      ac_more_lines=false
+    else
+      # The purpose of the label and of the branching condition is to
+      # speed up the sed processing (if there are no `@' at all, there
+      # is no need to browse any of the substitutions).
+      # These are the two extra sed commands mentioned above.
+      (echo ':t
+  /@[a-zA-Z_][a-zA-Z_0-9]*@/!b' && cat $tmp/subs.frag) >$tmp/subs-$ac_sed_frag.sed
+      if test -z "$ac_sed_cmds"; then
+	ac_sed_cmds="sed -f $tmp/subs-$ac_sed_frag.sed"
+      else
+	ac_sed_cmds="$ac_sed_cmds | sed -f $tmp/subs-$ac_sed_frag.sed"
+      fi
+      ac_sed_frag=`expr $ac_sed_frag + 1`
+      ac_beg=$ac_end
+      ac_end=`expr $ac_end + $ac_max_sed_lines`
+    fi
+  done
+  if test -z "$ac_sed_cmds"; then
+    ac_sed_cmds=cat
+  fi
+fi # test -n "$CONFIG_FILES"
+
+_ACEOF
+cat >>$CONFIG_STATUS <<\_ACEOF
+for ac_file in : $CONFIG_FILES; do test "x$ac_file" = x: && continue
+  # Support "outfile[:infile[:infile...]]", defaulting infile="outfile.in".
+  case $ac_file in
+  - | *:- | *:-:* ) # input from stdin
+	cat >$tmp/stdin
+	ac_file_in=`echo "$ac_file" | sed 's,[^:]*:,,'`
+	ac_file=`echo "$ac_file" | sed 's,:.*,,'` ;;
+  *:* ) ac_file_in=`echo "$ac_file" | sed 's,[^:]*:,,'`
+	ac_file=`echo "$ac_file" | sed 's,:.*,,'` ;;
+  * )   ac_file_in=$ac_file.in ;;
+  esac
+
+  # Compute @srcdir@, @top_srcdir@, and @INSTALL@ for subdirectories.
+  ac_dir=`(dirname "$ac_file") 2>/dev/null ||
+$as_expr X"$ac_file" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$ac_file" : 'X\(//\)[^/]' \| \
+	 X"$ac_file" : 'X\(//\)$' \| \
+	 X"$ac_file" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$ac_file" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+  { if $as_mkdir_p; then
+    mkdir -p "$ac_dir"
+  else
+    as_dir="$ac_dir"
+    as_dirs=
+    while test ! -d "$as_dir"; do
+      as_dirs="$as_dir $as_dirs"
+      as_dir=`(dirname "$as_dir") 2>/dev/null ||
+$as_expr X"$as_dir" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$as_dir" : 'X\(//\)[^/]' \| \
+	 X"$as_dir" : 'X\(//\)$' \| \
+	 X"$as_dir" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$as_dir" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+    done
+    test ! -n "$as_dirs" || mkdir $as_dirs
+  fi || { { echo "$as_me:$LINENO: error: cannot create directory \"$ac_dir\"" >&5
+echo "$as_me: error: cannot create directory \"$ac_dir\"" >&2;}
+   { (exit 1); exit 1; }; }; }
+
+  ac_builddir=.
+
+if test "$ac_dir" != .; then
+  ac_dir_suffix=/`echo "$ac_dir" | sed 's,^\.[\\/],,'`
+  # A "../" for each directory in $ac_dir_suffix.
+  ac_top_builddir=`echo "$ac_dir_suffix" | sed 's,/[^\\/]*,../,g'`
+else
+  ac_dir_suffix= ac_top_builddir=
+fi
+
+case $srcdir in
+  .)  # No --srcdir option.  We are building in place.
+    ac_srcdir=.
+    if test -z "$ac_top_builddir"; then
+       ac_top_srcdir=.
+    else
+       ac_top_srcdir=`echo $ac_top_builddir | sed 's,/$,,'`
+    fi ;;
+  [\\/]* | ?:[\\/]* )  # Absolute path.
+    ac_srcdir=$srcdir$ac_dir_suffix;
+    ac_top_srcdir=$srcdir ;;
+  *) # Relative path.
+    ac_srcdir=$ac_top_builddir$srcdir$ac_dir_suffix
+    ac_top_srcdir=$ac_top_builddir$srcdir ;;
+esac
+
+# Do not use `cd foo && pwd` to compute absolute paths, because
+# the directories may not exist.
+case `pwd` in
+.) ac_abs_builddir="$ac_dir";;
+*)
+  case "$ac_dir" in
+  .) ac_abs_builddir=`pwd`;;
+  [\\/]* | ?:[\\/]* ) ac_abs_builddir="$ac_dir";;
+  *) ac_abs_builddir=`pwd`/"$ac_dir";;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_builddir=${ac_top_builddir}.;;
+*)
+  case ${ac_top_builddir}. in
+  .) ac_abs_top_builddir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_builddir=${ac_top_builddir}.;;
+  *) ac_abs_top_builddir=$ac_abs_builddir/${ac_top_builddir}.;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_srcdir=$ac_srcdir;;
+*)
+  case $ac_srcdir in
+  .) ac_abs_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_srcdir=$ac_srcdir;;
+  *) ac_abs_srcdir=$ac_abs_builddir/$ac_srcdir;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_srcdir=$ac_top_srcdir;;
+*)
+  case $ac_top_srcdir in
+  .) ac_abs_top_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_srcdir=$ac_top_srcdir;;
+  *) ac_abs_top_srcdir=$ac_abs_builddir/$ac_top_srcdir;;
+  esac;;
+esac
+
+
+  case $INSTALL in
+  [\\/$]* | ?:[\\/]* ) ac_INSTALL=$INSTALL ;;
+  *) ac_INSTALL=$ac_top_builddir$INSTALL ;;
+  esac
+
+  if test x"$ac_file" != x-; then
+    { echo "$as_me:$LINENO: creating $ac_file" >&5
+echo "$as_me: creating $ac_file" >&6;}
+    rm -f "$ac_file"
+  fi
+  # Let's still pretend it is `configure' which instantiates (i.e., don't
+  # use $as_me), people would be surprised to read:
+  #    /* config.h.  Generated by config.status.  */
+  if test x"$ac_file" = x-; then
+    configure_input=
+  else
+    configure_input="$ac_file.  "
+  fi
+  configure_input=$configure_input"Generated from `echo $ac_file_in |
+				     sed 's,.*/,,'` by configure."
+
+  # First look for the input files in the build tree, otherwise in the
+  # src tree.
+  ac_file_inputs=`IFS=:
+    for f in $ac_file_in; do
+      case $f in
+      -) echo $tmp/stdin ;;
+      [\\/$]*)
+	 # Absolute (can't be DOS-style, as IFS=:)
+	 test -f "$f" || { { echo "$as_me:$LINENO: error: cannot find input file: $f" >&5
+echo "$as_me: error: cannot find input file: $f" >&2;}
+   { (exit 1); exit 1; }; }
+	 echo "$f";;
+      *) # Relative
+	 if test -f "$f"; then
+	   # Build tree
+	   echo "$f"
+	 elif test -f "$srcdir/$f"; then
+	   # Source tree
+	   echo "$srcdir/$f"
+	 else
+	   # /dev/null tree
+	   { { echo "$as_me:$LINENO: error: cannot find input file: $f" >&5
+echo "$as_me: error: cannot find input file: $f" >&2;}
+   { (exit 1); exit 1; }; }
+	 fi;;
+      esac
+    done` || { (exit 1); exit 1; }
+_ACEOF
+cat >>$CONFIG_STATUS <<_ACEOF
+  sed "$ac_vpsub
+$extrasub
+_ACEOF
+cat >>$CONFIG_STATUS <<\_ACEOF
+:t
+/@[a-zA-Z_][a-zA-Z_0-9]*@/!b
+s,@configure_input@,$configure_input,;t t
+s,@srcdir@,$ac_srcdir,;t t
+s,@abs_srcdir@,$ac_abs_srcdir,;t t
+s,@top_srcdir@,$ac_top_srcdir,;t t
+s,@abs_top_srcdir@,$ac_abs_top_srcdir,;t t
+s,@builddir@,$ac_builddir,;t t
+s,@abs_builddir@,$ac_abs_builddir,;t t
+s,@top_builddir@,$ac_top_builddir,;t t
+s,@abs_top_builddir@,$ac_abs_top_builddir,;t t
+s,@INSTALL@,$ac_INSTALL,;t t
+" $ac_file_inputs | (eval "$ac_sed_cmds") >$tmp/out
+  rm -f $tmp/stdin
+  if test x"$ac_file" != x-; then
+    mv $tmp/out $ac_file
+  else
+    cat $tmp/out
+    rm -f $tmp/out
+  fi
+
+done
+_ACEOF
+cat >>$CONFIG_STATUS <<\_ACEOF
+
+#
+# CONFIG_HEADER section.
+#
+
+# These sed commands are passed to sed as "A NAME B NAME C VALUE D", where
+# NAME is the cpp macro being defined and VALUE is the value it is being given.
+#
+# ac_d sets the value in "#define NAME VALUE" lines.
+ac_dA='s,^\([	 ]*\)#\([	 ]*define[	 ][	 ]*\)'
+ac_dB='[	 ].*$,\1#\2'
+ac_dC=' '
+ac_dD=',;t'
+# ac_u turns "#undef NAME" without trailing blanks into "#define NAME VALUE".
+ac_uA='s,^\([	 ]*\)#\([	 ]*\)undef\([	 ][	 ]*\)'
+ac_uB='$,\1#\2define\3'
+ac_uC=' '
+ac_uD=',;t'
+
+for ac_file in : $CONFIG_HEADERS; do test "x$ac_file" = x: && continue
+  # Support "outfile[:infile[:infile...]]", defaulting infile="outfile.in".
+  case $ac_file in
+  - | *:- | *:-:* ) # input from stdin
+	cat >$tmp/stdin
+	ac_file_in=`echo "$ac_file" | sed 's,[^:]*:,,'`
+	ac_file=`echo "$ac_file" | sed 's,:.*,,'` ;;
+  *:* ) ac_file_in=`echo "$ac_file" | sed 's,[^:]*:,,'`
+	ac_file=`echo "$ac_file" | sed 's,:.*,,'` ;;
+  * )   ac_file_in=$ac_file.in ;;
+  esac
+
+  test x"$ac_file" != x- && { echo "$as_me:$LINENO: creating $ac_file" >&5
+echo "$as_me: creating $ac_file" >&6;}
+
+  # First look for the input files in the build tree, otherwise in the
+  # src tree.
+  ac_file_inputs=`IFS=:
+    for f in $ac_file_in; do
+      case $f in
+      -) echo $tmp/stdin ;;
+      [\\/$]*)
+	 # Absolute (can't be DOS-style, as IFS=:)
+	 test -f "$f" || { { echo "$as_me:$LINENO: error: cannot find input file: $f" >&5
+echo "$as_me: error: cannot find input file: $f" >&2;}
+   { (exit 1); exit 1; }; }
+	 # Do quote $f, to prevent DOS paths from being IFS'd.
+	 echo "$f";;
+      *) # Relative
+	 if test -f "$f"; then
+	   # Build tree
+	   echo "$f"
+	 elif test -f "$srcdir/$f"; then
+	   # Source tree
+	   echo "$srcdir/$f"
+	 else
+	   # /dev/null tree
+	   { { echo "$as_me:$LINENO: error: cannot find input file: $f" >&5
+echo "$as_me: error: cannot find input file: $f" >&2;}
+   { (exit 1); exit 1; }; }
+	 fi;;
+      esac
+    done` || { (exit 1); exit 1; }
+  # Remove the trailing spaces.
+  sed 's/[	 ]*$//' $ac_file_inputs >$tmp/in
+
+_ACEOF
+
+# Transform confdefs.h into two sed scripts, `conftest.defines' and
+# `conftest.undefs', that substitutes the proper values into
+# config.h.in to produce config.h.  The first handles `#define'
+# templates, and the second `#undef' templates.
+# And first: Protect against being on the right side of a sed subst in
+# config.status.  Protect against being in an unquoted here document
+# in config.status.
+rm -f conftest.defines conftest.undefs
+# Using a here document instead of a string reduces the quoting nightmare.
+# Putting comments in sed scripts is not portable.
+#
+# `end' is used to avoid that the second main sed command (meant for
+# 0-ary CPP macros) applies to n-ary macro definitions.
+# See the Autoconf documentation for `clear'.
+cat >confdef2sed.sed <<\_ACEOF
+s/[\\&,]/\\&/g
+s,[\\$`],\\&,g
+t clear
+: clear
+s,^[	 ]*#[	 ]*define[	 ][	 ]*\([^	 (][^	 (]*\)\(([^)]*)\)[	 ]*\(.*\)$,${ac_dA}\1${ac_dB}\1\2${ac_dC}\3${ac_dD},gp
+t end
+s,^[	 ]*#[	 ]*define[	 ][	 ]*\([^	 ][^	 ]*\)[	 ]*\(.*\)$,${ac_dA}\1${ac_dB}\1${ac_dC}\2${ac_dD},gp
+: end
+_ACEOF
+# If some macros were called several times there might be several times
+# the same #defines, which is useless.  Nevertheless, we may not want to
+# sort them, since we want the *last* AC-DEFINE to be honored.
+uniq confdefs.h | sed -n -f confdef2sed.sed >conftest.defines
+sed 's/ac_d/ac_u/g' conftest.defines >conftest.undefs
+rm -f confdef2sed.sed
+
+# This sed command replaces #undef with comments.  This is necessary, for
+# example, in the case of _POSIX_SOURCE, which is predefined and required
+# on some systems where configure will not decide to define it.
+cat >>conftest.undefs <<\_ACEOF
+s,^[	 ]*#[	 ]*undef[	 ][	 ]*[a-zA-Z_][a-zA-Z_0-9]*,/* & */,
+_ACEOF
+
+# Break up conftest.defines because some shells have a limit on the size
+# of here documents, and old seds have small limits too (100 cmds).
+echo '  # Handle all the #define templates only if necessary.' >>$CONFIG_STATUS
+echo '  if grep "^[	 ]*#[	 ]*define" $tmp/in >/dev/null; then' >>$CONFIG_STATUS
+echo '  # If there are no defines, we may have an empty if/fi' >>$CONFIG_STATUS
+echo '  :' >>$CONFIG_STATUS
+rm -f conftest.tail
+while grep . conftest.defines >/dev/null
+do
+  # Write a limited-size here document to $tmp/defines.sed.
+  echo '  cat >$tmp/defines.sed <<CEOF' >>$CONFIG_STATUS
+  # Speed up: don't consider the non `#define' lines.
+  echo '/^[	 ]*#[	 ]*define/!b' >>$CONFIG_STATUS
+  # Work around the forget-to-reset-the-flag bug.
+  echo 't clr' >>$CONFIG_STATUS
+  echo ': clr' >>$CONFIG_STATUS
+  sed ${ac_max_here_lines}q conftest.defines >>$CONFIG_STATUS
+  echo 'CEOF
+  sed -f $tmp/defines.sed $tmp/in >$tmp/out
+  rm -f $tmp/in
+  mv $tmp/out $tmp/in
+' >>$CONFIG_STATUS
+  sed 1,${ac_max_here_lines}d conftest.defines >conftest.tail
+  rm -f conftest.defines
+  mv conftest.tail conftest.defines
+done
+rm -f conftest.defines
+echo '  fi # grep' >>$CONFIG_STATUS
+echo >>$CONFIG_STATUS
+
+# Break up conftest.undefs because some shells have a limit on the size
+# of here documents, and old seds have small limits too (100 cmds).
+echo '  # Handle all the #undef templates' >>$CONFIG_STATUS
+rm -f conftest.tail
+while grep . conftest.undefs >/dev/null
+do
+  # Write a limited-size here document to $tmp/undefs.sed.
+  echo '  cat >$tmp/undefs.sed <<CEOF' >>$CONFIG_STATUS
+  # Speed up: don't consider the non `#undef'
+  echo '/^[	 ]*#[	 ]*undef/!b' >>$CONFIG_STATUS
+  # Work around the forget-to-reset-the-flag bug.
+  echo 't clr' >>$CONFIG_STATUS
+  echo ': clr' >>$CONFIG_STATUS
+  sed ${ac_max_here_lines}q conftest.undefs >>$CONFIG_STATUS
+  echo 'CEOF
+  sed -f $tmp/undefs.sed $tmp/in >$tmp/out
+  rm -f $tmp/in
+  mv $tmp/out $tmp/in
+' >>$CONFIG_STATUS
+  sed 1,${ac_max_here_lines}d conftest.undefs >conftest.tail
+  rm -f conftest.undefs
+  mv conftest.tail conftest.undefs
+done
+rm -f conftest.undefs
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+  # Let's still pretend it is `configure' which instantiates (i.e., don't
+  # use $as_me), people would be surprised to read:
+  #    /* config.h.  Generated by config.status.  */
+  if test x"$ac_file" = x-; then
+    echo "/* Generated by configure.  */" >$tmp/config.h
+  else
+    echo "/* $ac_file.  Generated by configure.  */" >$tmp/config.h
+  fi
+  cat $tmp/in >>$tmp/config.h
+  rm -f $tmp/in
+  if test x"$ac_file" != x-; then
+    if diff $ac_file $tmp/config.h >/dev/null 2>&1; then
+      { echo "$as_me:$LINENO: $ac_file is unchanged" >&5
+echo "$as_me: $ac_file is unchanged" >&6;}
+    else
+      ac_dir=`(dirname "$ac_file") 2>/dev/null ||
+$as_expr X"$ac_file" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$ac_file" : 'X\(//\)[^/]' \| \
+	 X"$ac_file" : 'X\(//\)$' \| \
+	 X"$ac_file" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$ac_file" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+      { if $as_mkdir_p; then
+    mkdir -p "$ac_dir"
+  else
+    as_dir="$ac_dir"
+    as_dirs=
+    while test ! -d "$as_dir"; do
+      as_dirs="$as_dir $as_dirs"
+      as_dir=`(dirname "$as_dir") 2>/dev/null ||
+$as_expr X"$as_dir" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$as_dir" : 'X\(//\)[^/]' \| \
+	 X"$as_dir" : 'X\(//\)$' \| \
+	 X"$as_dir" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$as_dir" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+    done
+    test ! -n "$as_dirs" || mkdir $as_dirs
+  fi || { { echo "$as_me:$LINENO: error: cannot create directory \"$ac_dir\"" >&5
+echo "$as_me: error: cannot create directory \"$ac_dir\"" >&2;}
+   { (exit 1); exit 1; }; }; }
+
+      rm -f $ac_file
+      mv $tmp/config.h $ac_file
+    fi
+  else
+    cat $tmp/config.h
+    rm -f $tmp/config.h
+  fi
+# Compute $ac_file's index in $config_headers.
+_am_stamp_count=1
+for _am_header in $config_headers :; do
+  case $_am_header in
+    $ac_file | $ac_file:* )
+      break ;;
+    * )
+      _am_stamp_count=`expr $_am_stamp_count + 1` ;;
+  esac
+done
+echo "timestamp for $ac_file" >`(dirname $ac_file) 2>/dev/null ||
+$as_expr X$ac_file : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X$ac_file : 'X\(//\)[^/]' \| \
+	 X$ac_file : 'X\(//\)$' \| \
+	 X$ac_file : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X$ac_file |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`/stamp-h$_am_stamp_count
+done
+_ACEOF
+cat >>$CONFIG_STATUS <<\_ACEOF
+
+#
+# CONFIG_COMMANDS section.
+#
+for ac_file in : $CONFIG_COMMANDS; do test "x$ac_file" = x: && continue
+  ac_dest=`echo "$ac_file" | sed 's,:.*,,'`
+  ac_source=`echo "$ac_file" | sed 's,[^:]*:,,'`
+  ac_dir=`(dirname "$ac_dest") 2>/dev/null ||
+$as_expr X"$ac_dest" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$ac_dest" : 'X\(//\)[^/]' \| \
+	 X"$ac_dest" : 'X\(//\)$' \| \
+	 X"$ac_dest" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$ac_dest" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+  { if $as_mkdir_p; then
+    mkdir -p "$ac_dir"
+  else
+    as_dir="$ac_dir"
+    as_dirs=
+    while test ! -d "$as_dir"; do
+      as_dirs="$as_dir $as_dirs"
+      as_dir=`(dirname "$as_dir") 2>/dev/null ||
+$as_expr X"$as_dir" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$as_dir" : 'X\(//\)[^/]' \| \
+	 X"$as_dir" : 'X\(//\)$' \| \
+	 X"$as_dir" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$as_dir" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+    done
+    test ! -n "$as_dirs" || mkdir $as_dirs
+  fi || { { echo "$as_me:$LINENO: error: cannot create directory \"$ac_dir\"" >&5
+echo "$as_me: error: cannot create directory \"$ac_dir\"" >&2;}
+   { (exit 1); exit 1; }; }; }
+
+  ac_builddir=.
+
+if test "$ac_dir" != .; then
+  ac_dir_suffix=/`echo "$ac_dir" | sed 's,^\.[\\/],,'`
+  # A "../" for each directory in $ac_dir_suffix.
+  ac_top_builddir=`echo "$ac_dir_suffix" | sed 's,/[^\\/]*,../,g'`
+else
+  ac_dir_suffix= ac_top_builddir=
+fi
+
+case $srcdir in
+  .)  # No --srcdir option.  We are building in place.
+    ac_srcdir=.
+    if test -z "$ac_top_builddir"; then
+       ac_top_srcdir=.
+    else
+       ac_top_srcdir=`echo $ac_top_builddir | sed 's,/$,,'`
+    fi ;;
+  [\\/]* | ?:[\\/]* )  # Absolute path.
+    ac_srcdir=$srcdir$ac_dir_suffix;
+    ac_top_srcdir=$srcdir ;;
+  *) # Relative path.
+    ac_srcdir=$ac_top_builddir$srcdir$ac_dir_suffix
+    ac_top_srcdir=$ac_top_builddir$srcdir ;;
+esac
+
+# Do not use `cd foo && pwd` to compute absolute paths, because
+# the directories may not exist.
+case `pwd` in
+.) ac_abs_builddir="$ac_dir";;
+*)
+  case "$ac_dir" in
+  .) ac_abs_builddir=`pwd`;;
+  [\\/]* | ?:[\\/]* ) ac_abs_builddir="$ac_dir";;
+  *) ac_abs_builddir=`pwd`/"$ac_dir";;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_builddir=${ac_top_builddir}.;;
+*)
+  case ${ac_top_builddir}. in
+  .) ac_abs_top_builddir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_builddir=${ac_top_builddir}.;;
+  *) ac_abs_top_builddir=$ac_abs_builddir/${ac_top_builddir}.;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_srcdir=$ac_srcdir;;
+*)
+  case $ac_srcdir in
+  .) ac_abs_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_srcdir=$ac_srcdir;;
+  *) ac_abs_srcdir=$ac_abs_builddir/$ac_srcdir;;
+  esac;;
+esac
+case $ac_abs_builddir in
+.) ac_abs_top_srcdir=$ac_top_srcdir;;
+*)
+  case $ac_top_srcdir in
+  .) ac_abs_top_srcdir=$ac_abs_builddir;;
+  [\\/]* | ?:[\\/]* ) ac_abs_top_srcdir=$ac_top_srcdir;;
+  *) ac_abs_top_srcdir=$ac_abs_builddir/$ac_top_srcdir;;
+  esac;;
+esac
+
+
+  { echo "$as_me:$LINENO: executing $ac_dest commands" >&5
+echo "$as_me: executing $ac_dest commands" >&6;}
+  case $ac_dest in
+    depfiles ) test x"$AMDEP_TRUE" != x"" || for mf in $CONFIG_FILES; do
+  # Strip MF so we end up with the name of the file.
+  mf=`echo "$mf" | sed -e 's/:.*$//'`
+  # Check whether this is an Automake generated Makefile or not.
+  # We used to match only the files named `Makefile.in', but
+  # some people rename them; so instead we look at the file content.
+  # Grep'ing the first line is not enough: some people post-process
+  # each Makefile.in and add a new line on top of each file to say so.
+  # So let's grep whole file.
+  if grep '^#.*generated by automake' $mf > /dev/null 2>&1; then
+    dirpart=`(dirname "$mf") 2>/dev/null ||
+$as_expr X"$mf" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$mf" : 'X\(//\)[^/]' \| \
+	 X"$mf" : 'X\(//\)$' \| \
+	 X"$mf" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$mf" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+  else
+    continue
+  fi
+  # Extract the definition of DEPDIR, am__include, and am__quote
+  # from the Makefile without running `make'.
+  DEPDIR=`sed -n 's/^DEPDIR = //p' < "$mf"`
+  test -z "$DEPDIR" && continue
+  am__include=`sed -n 's/^am__include = //p' < "$mf"`
+  test -z "am__include" && continue
+  am__quote=`sed -n 's/^am__quote = //p' < "$mf"`
+  # When using ansi2knr, U may be empty or an underscore; expand it
+  U=`sed -n 's/^U = //p' < "$mf"`
+  # Find all dependency output files, they are included files with
+  # $(DEPDIR) in their names.  We invoke sed twice because it is the
+  # simplest approach to changing $(DEPDIR) to its actual value in the
+  # expansion.
+  for file in `sed -n "
+    s/^$am__include $am__quote\(.*(DEPDIR).*\)$am__quote"'$/\1/p' <"$mf" | \
+       sed -e 's/\$(DEPDIR)/'"$DEPDIR"'/g' -e 's/\$U/'"$U"'/g'`; do
+    # Make sure the directory exists.
+    test -f "$dirpart/$file" && continue
+    fdir=`(dirname "$file") 2>/dev/null ||
+$as_expr X"$file" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$file" : 'X\(//\)[^/]' \| \
+	 X"$file" : 'X\(//\)$' \| \
+	 X"$file" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$file" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+    { if $as_mkdir_p; then
+    mkdir -p $dirpart/$fdir
+  else
+    as_dir=$dirpart/$fdir
+    as_dirs=
+    while test ! -d "$as_dir"; do
+      as_dirs="$as_dir $as_dirs"
+      as_dir=`(dirname "$as_dir") 2>/dev/null ||
+$as_expr X"$as_dir" : 'X\(.*[^/]\)//*[^/][^/]*/*$' \| \
+	 X"$as_dir" : 'X\(//\)[^/]' \| \
+	 X"$as_dir" : 'X\(//\)$' \| \
+	 X"$as_dir" : 'X\(/\)' \| \
+	 .     : '\(.\)' 2>/dev/null ||
+echo X"$as_dir" |
+    sed '/^X\(.*[^/]\)\/\/*[^/][^/]*\/*$/{ s//\1/; q; }
+  	  /^X\(\/\/\)[^/].*/{ s//\1/; q; }
+  	  /^X\(\/\/\)$/{ s//\1/; q; }
+  	  /^X\(\/\).*/{ s//\1/; q; }
+  	  s/.*/./; q'`
+    done
+    test ! -n "$as_dirs" || mkdir $as_dirs
+  fi || { { echo "$as_me:$LINENO: error: cannot create directory $dirpart/$fdir" >&5
+echo "$as_me: error: cannot create directory $dirpart/$fdir" >&2;}
+   { (exit 1); exit 1; }; }; }
+
+    # echo "creating $dirpart/$file"
+    echo '# dummy' > "$dirpart/$file"
+  done
+done
+ ;;
+  esac
+done
+_ACEOF
+
+cat >>$CONFIG_STATUS <<\_ACEOF
+
+{ (exit 0); exit 0; }
+_ACEOF
+chmod +x $CONFIG_STATUS
+ac_clean_files=$ac_clean_files_save
+
+
+# configure is writing to config.log, and then calls config.status.
+# config.status does its own redirection, appending to config.log.
+# Unfortunately, on DOS this fails, as config.log is still kept open
+# by configure, so config.status won't be able to write to it; its
+# output is simply discarded.  So we exec the FD to /dev/null,
+# effectively closing config.log, so it can be properly (re)opened and
+# appended to by config.status.  When coming back to configure, we
+# need to make the FD available again.
+if test "$no_create" != yes; then
+  ac_cs_success=:
+  ac_config_status_args=
+  test "$silent" = yes &&
+    ac_config_status_args="$ac_config_status_args --quiet"
+  exec 5>/dev/null
+  $SHELL $CONFIG_STATUS $ac_config_status_args || ac_cs_success=false
+  exec 5>>config.log
+  # Use ||, not &&, to avoid exiting from the if with $? = 1, which
+  # would make configure fail if this is the last instruction.
+  $ac_cs_success || { (exit 1); exit 1; }
+fi
+
diff --git a/libevent/configure.in b/libevent/configure.in
new file mode 100644
index 0000000..852d3c5
--- /dev/null
+++ b/libevent/configure.in
@@ -0,0 +1,385 @@
+dnl configure.in for libevent
+dnl Dug Song <dugsong@monkey.org>
+AC_INIT(event.c)
+
+AM_INIT_AUTOMAKE(libevent,1.4.8-stable)
+AM_CONFIG_HEADER(config.h)
+dnl AM_MAINTAINER_MODE
+
+dnl Initialize prefix.
+if test "$prefix" = "NONE"; then
+   prefix="/usr/local"
+fi
+
+dnl Checks for programs.
+AC_PROG_CC
+AC_PROG_INSTALL
+AC_PROG_LN_S
+
+AC_PROG_GCC_TRADITIONAL
+#if test "$GCC" = yes ; then
+#        CFLAGS="$CFLAGS -Wall"
+#fi
+
+AC_ARG_ENABLE(gcc-warnings,
+     AS_HELP_STRING(--enable-gcc-warnings, enable verbose warnings with GCC))
+
+AC_PROG_RANLIB
+
+dnl   Uncomment "AC_DISABLE_SHARED" to make shared librraries not get
+dnl   built by default.  You can also turn shared libs on and off from 
+dnl   the command line with --enable-shared and --disable-shared.
+dnl AC_DISABLE_SHARED
+dnl AC_SUBST(LIBTOOL_DEPS)
+
+dnl Checks for libraries.
+AC_CHECK_LIB(socket, socket)
+AC_CHECK_LIB(resolv, inet_aton)
+AC_CHECK_LIB(rt, clock_gettime)
+AC_CHECK_LIB(nsl, inet_ntoa)
+
+dnl Checks for header files.
+AC_HEADER_STDC
+AC_CHECK_HEADERS(fcntl.h stdarg.h inttypes.h stdint.h poll.h signal.h unistd.h sys/epoll.h sys/time.h sys/queue.h sys/event.h sys/param.h sys/ioctl.h sys/select.h sys/devpoll.h port.h netinet/in6.h sys/socket.h)
+if test "x$ac_cv_header_sys_queue_h" = "xyes"; then
+	AC_MSG_CHECKING(for TAILQ_FOREACH in sys/queue.h)
+	AC_EGREP_CPP(yes,
+[
+#include <sys/queue.h>
+#ifdef TAILQ_FOREACH
+ yes
+#endif
+],	[AC_MSG_RESULT(yes)
+	 AC_DEFINE(HAVE_TAILQFOREACH, 1,
+		[Define if TAILQ_FOREACH is defined in <sys/queue.h>])],
+	AC_MSG_RESULT(no)
+	)
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	AC_MSG_CHECKING(for timeradd in sys/time.h)
+	AC_EGREP_CPP(yes,
+[
+#include <sys/time.h>
+#ifdef timeradd
+ yes
+#endif
+],	[ AC_DEFINE(HAVE_TIMERADD, 1,
+		[Define if timeradd is defined in <sys/time.h>])
+	  AC_MSG_RESULT(yes)] ,AC_MSG_RESULT(no)
+)
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	AC_MSG_CHECKING(for timercmp in sys/time.h)
+	AC_EGREP_CPP(yes,
+[
+#include <sys/time.h>
+#ifdef timercmp
+ yes
+#endif
+],	[ AC_DEFINE(HAVE_TIMERCMP, 1,
+		[Define if timercmp is defined in <sys/time.h>])
+	  AC_MSG_RESULT(yes)] ,AC_MSG_RESULT(no)
+)
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	AC_MSG_CHECKING(for timerclear in sys/time.h)
+	AC_EGREP_CPP(yes,
+[
+#include <sys/time.h>
+#ifdef timerclear
+ yes
+#endif
+],	[ AC_DEFINE(HAVE_TIMERCLEAR, 1,
+		[Define if timerclear is defined in <sys/time.h>])
+	  AC_MSG_RESULT(yes)] ,AC_MSG_RESULT(no)
+)
+fi
+
+if test "x$ac_cv_header_sys_time_h" = "xyes"; then
+	AC_MSG_CHECKING(for timerisset in sys/time.h)
+	AC_EGREP_CPP(yes,
+[
+#include <sys/time.h>
+#ifdef timerisset
+ yes
+#endif
+],	[ AC_DEFINE(HAVE_TIMERISSET, 1,
+		[Define if timerisset is defined in <sys/time.h>])
+	  AC_MSG_RESULT(yes)] ,AC_MSG_RESULT(no)
+)
+fi
+
+dnl - check if the macro WIN32 is defined on this compiler.
+dnl - (this is how we check for a windows version of GCC)
+AC_MSG_CHECKING(for WIN32)
+AC_TRY_COMPILE(,
+	[
+#ifndef WIN32
+die horribly
+#endif
+	],
+	bwin32=true; AC_MSG_RESULT(yes),
+	bwin32=false; AC_MSG_RESULT(no),
+)
+
+AM_CONDITIONAL(BUILD_WIN32, test x$bwin32 = xtrue)
+
+dnl Checks for typedefs, structures, and compiler characteristics.
+AC_C_CONST
+AC_C_INLINE
+AC_HEADER_TIME
+
+dnl Checks for library functions.
+AC_CHECK_FUNCS(gettimeofday vasprintf fcntl clock_gettime strtok_r strsep getaddrinfo getnameinfo strlcpy inet_ntop signal sigaction strtoll)
+
+AC_CHECK_SIZEOF(long)
+
+if test "x$ac_cv_func_clock_gettime" = "xyes"; then
+   AC_DEFINE(DNS_USE_CPU_CLOCK_FOR_ID, 1, [Define if clock_gettime is available in libc])
+else
+   AC_DEFINE(DNS_USE_GETTIMEOFDAY_FOR_ID, 1, [Define is no secure id variant is available])
+fi
+
+AC_MSG_CHECKING(for F_SETFD in fcntl.h)
+AC_EGREP_CPP(yes,
+[
+#define _GNU_SOURCE
+#include <fcntl.h>
+#ifdef F_SETFD
+yes
+#endif
+],	[ AC_DEFINE(HAVE_SETFD, 1,
+	      [Define if F_SETFD is defined in <fcntl.h>])
+	  AC_MSG_RESULT(yes) ], AC_MSG_RESULT(no))
+
+needsignal=no
+haveselect=no
+AC_CHECK_FUNCS(select, [haveselect=yes], )
+if test "x$haveselect" = "xyes" ; then
+	AC_LIBOBJ(select)
+	needsignal=yes
+fi
+
+havepoll=no
+AC_CHECK_FUNCS(poll, [havepoll=yes], )
+if test "x$havepoll" = "xyes" ; then
+	AC_LIBOBJ(poll)
+	needsignal=yes
+fi
+
+haveepoll=no
+AC_CHECK_FUNCS(epoll_ctl, [haveepoll=yes], )
+if test "x$haveepoll" = "xyes" ; then
+	AC_DEFINE(HAVE_EPOLL, 1,
+		[Define if your system supports the epoll system calls])
+	AC_LIBOBJ(epoll)
+	needsignal=yes
+fi
+
+havedevpoll=no
+if test "x$ac_cv_header_sys_devpoll_h" = "xyes"; then
+	AC_DEFINE(HAVE_DEVPOLL, 1,
+		    [Define if /dev/poll is available])
+        AC_LIBOBJ(devpoll)
+fi
+
+havekqueue=no
+if test "x$ac_cv_header_sys_event_h" = "xyes"; then
+	AC_CHECK_FUNCS(kqueue, [havekqueue=yes], )
+	if test "x$havekqueue" = "xyes" ; then
+		AC_MSG_CHECKING(for working kqueue)
+		AC_TRY_RUN(
+#include <sys/types.h>
+#include <sys/time.h>
+#include <sys/event.h>
+#include <stdio.h>
+#include <unistd.h>
+#include <fcntl.h>
+
+int
+main(int argc, char **argv)
+{
+	int kq;
+	int n;
+	int fd[[2]];
+	struct kevent ev;
+	struct timespec ts;
+	char buf[[8000]];
+
+	if (pipe(fd) == -1)
+		exit(1);
+	if (fcntl(fd[[1]], F_SETFL, O_NONBLOCK) == -1)
+		exit(1);
+
+	while ((n = write(fd[[1]], buf, sizeof(buf))) == sizeof(buf))
+		;
+
+        if ((kq = kqueue()) == -1)
+		exit(1);
+
+	ev.ident = fd[[1]];
+	ev.filter = EVFILT_WRITE;
+	ev.flags = EV_ADD | EV_ENABLE;
+	n = kevent(kq, &ev, 1, NULL, 0, NULL);
+	if (n == -1)
+		exit(1);
+	
+	read(fd[[0]], buf, sizeof(buf));
+
+	ts.tv_sec = 0;
+	ts.tv_nsec = 0;
+	n = kevent(kq, NULL, 0, &ev, 1, &ts);
+	if (n == -1 || n == 0)
+		exit(1);
+
+	exit(0);
+}, [AC_MSG_RESULT(yes)
+    AC_DEFINE(HAVE_WORKING_KQUEUE, 1,
+		[Define if kqueue works correctly with pipes])
+    AC_LIBOBJ(kqueue)], AC_MSG_RESULT(no), AC_MSG_RESULT(no))
+	fi
+fi
+
+haveepollsyscall=no
+if test "x$ac_cv_header_sys_epoll_h" = "xyes"; then
+	if test "x$haveepoll" = "xno" ; then
+		AC_MSG_CHECKING(for epoll system call)
+		AC_TRY_RUN(
+#include <stdint.h>
+#include <sys/param.h>
+#include <sys/types.h>
+#include <sys/syscall.h>
+#include <sys/epoll.h>
+#include <unistd.h>
+
+int
+epoll_create(int size)
+{
+	return (syscall(__NR_epoll_create, size));
+}
+
+int
+main(int argc, char **argv)
+{
+	int epfd;
+
+	epfd = epoll_create(256);
+	exit (epfd == -1 ? 1 : 0);
+}, [AC_MSG_RESULT(yes)
+    AC_DEFINE(HAVE_EPOLL, 1,
+	[Define if your system supports the epoll system calls])
+    needsignal=yes
+    AC_LIBOBJ(epoll_sub)
+    AC_LIBOBJ(epoll)], AC_MSG_RESULT(no), AC_MSG_RESULT(no))
+	fi
+fi
+
+haveeventports=no
+AC_CHECK_FUNCS(port_create, [haveeventports=yes], )
+if test "x$haveeventports" = "xyes" ; then
+	AC_DEFINE(HAVE_EVENT_PORTS, 1,
+		[Define if your system supports event ports])
+	AC_LIBOBJ(evport)
+	needsignal=yes
+fi
+if test "x$bwin32" = "xtrue"; then
+	needsignal=yes
+fi
+if test "x$bwin32" = "xtrue"; then
+	needsignal=yes
+fi
+if test "x$needsignal" = "xyes" ; then
+	AC_LIBOBJ(signal)
+fi
+
+AC_TYPE_PID_T
+AC_TYPE_SIZE_T
+AC_CHECK_TYPES([uint64_t, uint32_t, uint16_t, uint8_t], , ,
+[#ifdef HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif])
+AC_CHECK_SIZEOF(long long)
+AC_CHECK_SIZEOF(long)   
+AC_CHECK_SIZEOF(int)
+AC_CHECK_SIZEOF(short)
+AC_CHECK_TYPES([struct in6_addr], , ,
+[#ifdef WIN32
+#include <winsock2.h>
+#else
+#include <sys/types.h>
+#include <netinet/in.h>
+#include <sys/socket.h>
+#endif
+#ifdef HAVE_NETINET_IN6_H
+#include <netinet/in6.h>
+#endif])
+
+AC_MSG_CHECKING([for socklen_t])
+AC_TRY_COMPILE([
+ #include <sys/types.h>
+ #include <sys/socket.h>],
+  [socklen_t x;],
+  AC_MSG_RESULT([yes]),
+  [AC_MSG_RESULT([no])
+  AC_DEFINE(socklen_t, unsigned int,
+	[Define to unsigned int if you dont have it])]
+)
+
+AC_MSG_CHECKING([whether our compiler supports __func__])
+AC_TRY_COMPILE([],
+ [ const char *cp = __func__; ],
+ AC_MSG_RESULT([yes]),
+ AC_MSG_RESULT([no])
+ AC_MSG_CHECKING([whether our compiler supports __FUNCTION__])
+ AC_TRY_COMPILE([],
+   [ const char *cp = __FUNCTION__; ],
+   AC_MSG_RESULT([yes])
+   AC_DEFINE(__func__, __FUNCTION__,
+         [Define to appropriate substitue if compiler doesnt have __func__]),
+   AC_MSG_RESULT([no])
+   AC_DEFINE(__func__, __FILE__,
+         [Define to appropriate substitue if compiler doesnt have __func__])))
+
+
+# Add some more warnings which we use in development but not in the
+# released versions.  (Some relevant gcc versions can't handle these.)
+if test x$enable_gcc_warnings = xyes; then
+
+  AC_COMPILE_IFELSE(AC_LANG_PROGRAM([], [
+#if !defined(__GNUC__) || (__GNUC__ < 4)
+#error
+#endif]), have_gcc4=yes, have_gcc4=no)
+
+  AC_COMPILE_IFELSE(AC_LANG_PROGRAM([], [
+#if !defined(__GNUC__) || (__GNUC__ < 4) || (__GNUC__ == 4 && __GNUC_MINOR__ < 2)
+#error
+#endif]), have_gcc42=yes, have_gcc42=no)
+
+  CFLAGS="$CFLAGS -W -Wfloat-equal -Wundef -Wpointer-arith -Wstrict-prototypes -Wmissing-prototypes -Wwrite-strings -Wredundant-decls -Wchar-subscripts -Wcomment -Wformat=2 -Wwrite-strings -Wmissing-declarations -Wredundant-decls -Wnested-externs -Wbad-function-cast -Wswitch-enum -Werror"
+  CFLAGS="$CFLAGS -Wno-unused-parameter -Wno-sign-compare -Wstrict-aliasing"
+
+  if test x$have_gcc4 = xyes ; then 
+    # These warnings break gcc 3.3.5 and work on gcc 4.0.2
+    CFLAGS="$CFLAGS -Winit-self -Wmissing-field-initializers -Wdeclaration-after-statement"
+    #CFLAGS="$CFLAGS -Wold-style-definition"
+  fi
+
+  if test x$have_gcc42 = xyes ; then 
+    # These warnings break gcc 4.0.2 and work on gcc 4.2
+    CFLAGS="$CFLAGS -Waddress -Wnormalized=id -Woverride-init"
+  fi
+
+##This will break the world on some 64-bit architectures
+# CFLAGS="$CFLAGS -Winline"
+
+fi
+
+AC_OUTPUT(Makefile)
diff --git a/libevent/depcomp b/libevent/depcomp
new file mode 100644
index 0000000..ffcd540
--- /dev/null
+++ b/libevent/depcomp
@@ -0,0 +1,529 @@
+#! /bin/sh
+# depcomp - compile a program generating dependencies as side-effects
+
+scriptversion=2005-02-09.22
+
+# Copyright (C) 1999, 2000, 2003, 2004, 2005 Free Software Foundation, Inc.
+
+# This program is free software; you can redistribute it and/or modify
+# it under the terms of the GNU General Public License as published by
+# the Free Software Foundation; either version 2, or (at your option)
+# any later version.
+
+# This program is distributed in the hope that it will be useful,
+# but WITHOUT ANY WARRANTY; without even the implied warranty of
+# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+# GNU General Public License for more details.
+
+# You should have received a copy of the GNU General Public License
+# along with this program; if not, write to the Free Software
+# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
+# 02111-1307, USA.
+
+# As a special exception to the GNU General Public License, if you
+# distribute this file as part of a program that contains a
+# configuration script generated by Autoconf, you may include it under
+# the same distribution terms that you use for the rest of that program.
+
+# Originally written by Alexandre Oliva <oliva@dcc.unicamp.br>.
+
+case $1 in
+  '')
+     echo "$0: No command.  Try \`$0 --help' for more information." 1>&2
+     exit 1;
+     ;;
+  -h | --h*)
+    cat <<\EOF
+Usage: depcomp [--help] [--version] PROGRAM [ARGS]
+
+Run PROGRAMS ARGS to compile a file, generating dependencies
+as side-effects.
+
+Environment variables:
+  depmode     Dependency tracking mode.
+  source      Source file read by `PROGRAMS ARGS'.
+  object      Object file output by `PROGRAMS ARGS'.
+  DEPDIR      directory where to store dependencies.
+  depfile     Dependency file to output.
+  tmpdepfile  Temporary file to use when outputing dependencies.
+  libtool     Whether libtool is used (yes/no).
+
+Report bugs to <bug-automake@gnu.org>.
+EOF
+    exit $?
+    ;;
+  -v | --v*)
+    echo "depcomp $scriptversion"
+    exit $?
+    ;;
+esac
+
+if test -z "$depmode" || test -z "$source" || test -z "$object"; then
+  echo "depcomp: Variables source, object and depmode must be set" 1>&2
+  exit 1
+fi
+
+# Dependencies for sub/bar.o or sub/bar.obj go into sub/.deps/bar.Po.
+depfile=${depfile-`echo "$object" |
+  sed 's|[^\\/]*$|'${DEPDIR-.deps}'/&|;s|\.\([^.]*\)$|.P\1|;s|Pobj$|Po|'`}
+tmpdepfile=${tmpdepfile-`echo "$depfile" | sed 's/\.\([^.]*\)$/.T\1/'`}
+
+rm -f "$tmpdepfile"
+
+# Some modes work just like other modes, but use different flags.  We
+# parameterize here, but still list the modes in the big case below,
+# to make depend.m4 easier to write.  Note that we *cannot* use a case
+# here, because this file can only contain one case statement.
+if test "$depmode" = hp; then
+  # HP compiler uses -M and no extra arg.
+  gccflag=-M
+  depmode=gcc
+fi
+
+if test "$depmode" = dashXmstdout; then
+   # This is just like dashmstdout with a different argument.
+   dashmflag=-xM
+   depmode=dashmstdout
+fi
+
+case "$depmode" in
+gcc3)
+## gcc 3 implements dependency tracking that does exactly what
+## we want.  Yay!  Note: for some reason libtool 1.4 doesn't like
+## it if -MD -MP comes after the -MF stuff.  Hmm.
+  "$@" -MT "$object" -MD -MP -MF "$tmpdepfile"
+  stat=$?
+  if test $stat -eq 0; then :
+  else
+    rm -f "$tmpdepfile"
+    exit $stat
+  fi
+  mv "$tmpdepfile" "$depfile"
+  ;;
+
+gcc)
+## There are various ways to get dependency output from gcc.  Here's
+## why we pick this rather obscure method:
+## - Don't want to use -MD because we'd like the dependencies to end
+##   up in a subdir.  Having to rename by hand is ugly.
+##   (We might end up doing this anyway to support other compilers.)
+## - The DEPENDENCIES_OUTPUT environment variable makes gcc act like
+##   -MM, not -M (despite what the docs say).
+## - Using -M directly means running the compiler twice (even worse
+##   than renaming).
+  if test -z "$gccflag"; then
+    gccflag=-MD,
+  fi
+  "$@" -Wp,"$gccflag$tmpdepfile"
+  stat=$?
+  if test $stat -eq 0; then :
+  else
+    rm -f "$tmpdepfile"
+    exit $stat
+  fi
+  rm -f "$depfile"
+  echo "$object : \\" > "$depfile"
+  alpha=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
+## The second -e expression handles DOS-style file names with drive letters.
+  sed -e 's/^[^:]*: / /' \
+      -e 's/^['$alpha']:\/[^:]*: / /' < "$tmpdepfile" >> "$depfile"
+## This next piece of magic avoids the `deleted header file' problem.
+## The problem is that when a header file which appears in a .P file
+## is deleted, the dependency causes make to die (because there is
+## typically no way to rebuild the header).  We avoid this by adding
+## dummy dependencies for each header file.  Too bad gcc doesn't do
+## this for us directly.
+  tr ' ' '
+' < "$tmpdepfile" |
+## Some versions of gcc put a space before the `:'.  On the theory
+## that the space means something, we add a space to the output as
+## well.
+## Some versions of the HPUX 10.20 sed can't process this invocation
+## correctly.  Breaking it into two sed invocations is a workaround.
+    sed -e 's/^\\$//' -e '/^$/d' -e '/:$/d' | sed -e 's/$/ :/' >> "$depfile"
+  rm -f "$tmpdepfile"
+  ;;
+
+hp)
+  # This case exists only to let depend.m4 do its work.  It works by
+  # looking at the text of this script.  This case will never be run,
+  # since it is checked for above.
+  exit 1
+  ;;
+
+sgi)
+  if test "$libtool" = yes; then
+    "$@" "-Wp,-MDupdate,$tmpdepfile"
+  else
+    "$@" -MDupdate "$tmpdepfile"
+  fi
+  stat=$?
+  if test $stat -eq 0; then :
+  else
+    rm -f "$tmpdepfile"
+    exit $stat
+  fi
+  rm -f "$depfile"
+
+  if test -f "$tmpdepfile"; then  # yes, the sourcefile depend on other files
+    echo "$object : \\" > "$depfile"
+
+    # Clip off the initial element (the dependent).  Don't try to be
+    # clever and replace this with sed code, as IRIX sed won't handle
+    # lines with more than a fixed number of characters (4096 in
+    # IRIX 6.2 sed, 8192 in IRIX 6.5).  We also remove comment lines;
+    # the IRIX cc adds comments like `#:fec' to the end of the
+    # dependency line.
+    tr ' ' '
+' < "$tmpdepfile" \
+    | sed -e 's/^.*\.o://' -e 's/#.*$//' -e '/^$/ d' | \
+    tr '
+' ' ' >> $depfile
+    echo >> $depfile
+
+    # The second pass generates a dummy entry for each header file.
+    tr ' ' '
+' < "$tmpdepfile" \
+   | sed -e 's/^.*\.o://' -e 's/#.*$//' -e '/^$/ d' -e 's/$/:/' \
+   >> $depfile
+  else
+    # The sourcefile does not contain any dependencies, so just
+    # store a dummy comment line, to avoid errors with the Makefile
+    # "include basename.Plo" scheme.
+    echo "#dummy" > "$depfile"
+  fi
+  rm -f "$tmpdepfile"
+  ;;
+
+aix)
+  # The C for AIX Compiler uses -M and outputs the dependencies
+  # in a .u file.  In older versions, this file always lives in the
+  # current directory.  Also, the AIX compiler puts `$object:' at the
+  # start of each line; $object doesn't have directory information.
+  # Version 6 uses the directory in both cases.
+  stripped=`echo "$object" | sed 's/\(.*\)\..*$/\1/'`
+  tmpdepfile="$stripped.u"
+  if test "$libtool" = yes; then
+    "$@" -Wc,-M
+  else
+    "$@" -M
+  fi
+  stat=$?
+
+  if test -f "$tmpdepfile"; then :
+  else
+    stripped=`echo "$stripped" | sed 's,^.*/,,'`
+    tmpdepfile="$stripped.u"
+  fi
+
+  if test $stat -eq 0; then :
+  else
+    rm -f "$tmpdepfile"
+    exit $stat
+  fi
+
+  if test -f "$tmpdepfile"; then
+    outname="$stripped.o"
+    # Each line is of the form `foo.o: dependent.h'.
+    # Do two passes, one to just change these to
+    # `$object: dependent.h' and one to simply `dependent.h:'.
+    sed -e "s,^$outname:,$object :," < "$tmpdepfile" > "$depfile"
+    sed -e "s,^$outname: \(.*\)$,\1:," < "$tmpdepfile" >> "$depfile"
+  else
+    # The sourcefile does not contain any dependencies, so just
+    # store a dummy comment line, to avoid errors with the Makefile
+    # "include basename.Plo" scheme.
+    echo "#dummy" > "$depfile"
+  fi
+  rm -f "$tmpdepfile"
+  ;;
+
+icc)
+  # Intel's C compiler understands `-MD -MF file'.  However on
+  #    icc -MD -MF foo.d -c -o sub/foo.o sub/foo.c
+  # ICC 7.0 will fill foo.d with something like
+  #    foo.o: sub/foo.c
+  #    foo.o: sub/foo.h
+  # which is wrong.  We want:
+  #    sub/foo.o: sub/foo.c
+  #    sub/foo.o: sub/foo.h
+  #    sub/foo.c:
+  #    sub/foo.h:
+  # ICC 7.1 will output
+  #    foo.o: sub/foo.c sub/foo.h
+  # and will wrap long lines using \ :
+  #    foo.o: sub/foo.c ... \
+  #     sub/foo.h ... \
+  #     ...
+
+  "$@" -MD -MF "$tmpdepfile"
+  stat=$?
+  if test $stat -eq 0; then :
+  else
+    rm -f "$tmpdepfile"
+    exit $stat
+  fi
+  rm -f "$depfile"
+  # Each line is of the form `foo.o: dependent.h',
+  # or `foo.o: dep1.h dep2.h \', or ` dep3.h dep4.h \'.
+  # Do two passes, one to just change these to
+  # `$object: dependent.h' and one to simply `dependent.h:'.
+  sed "s,^[^:]*:,$object :," < "$tmpdepfile" > "$depfile"
+  # Some versions of the HPUX 10.20 sed can't process this invocation
+  # correctly.  Breaking it into two sed invocations is a workaround.
+  sed 's,^[^:]*: \(.*\)$,\1,;s/^\\$//;/^$/d;/:$/d' < "$tmpdepfile" |
+    sed -e 's/$/ :/' >> "$depfile"
+  rm -f "$tmpdepfile"
+  ;;
+
+tru64)
+   # The Tru64 compiler uses -MD to generate dependencies as a side
+   # effect.  `cc -MD -o foo.o ...' puts the dependencies into `foo.o.d'.
+   # At least on Alpha/Redhat 6.1, Compaq CCC V6.2-504 seems to put
+   # dependencies in `foo.d' instead, so we check for that too.
+   # Subdirectories are respected.
+   dir=`echo "$object" | sed -e 's|/[^/]*$|/|'`
+   test "x$dir" = "x$object" && dir=
+   base=`echo "$object" | sed -e 's|^.*/||' -e 's/\.o$//' -e 's/\.lo$//'`
+
+   if test "$libtool" = yes; then
+      # With Tru64 cc, shared objects can also be used to make a
+      # static library.  This mecanism is used in libtool 1.4 series to
+      # handle both shared and static libraries in a single compilation.
+      # With libtool 1.4, dependencies were output in $dir.libs/$base.lo.d.
+      #
+      # With libtool 1.5 this exception was removed, and libtool now
+      # generates 2 separate objects for the 2 libraries.  These two
+      # compilations output dependencies in in $dir.libs/$base.o.d and
+      # in $dir$base.o.d.  We have to check for both files, because
+      # one of the two compilations can be disabled.  We should prefer
+      # $dir$base.o.d over $dir.libs/$base.o.d because the latter is
+      # automatically cleaned when .libs/ is deleted, while ignoring
+      # the former would cause a distcleancheck panic.
+      tmpdepfile1=$dir.libs/$base.lo.d   # libtool 1.4
+      tmpdepfile2=$dir$base.o.d          # libtool 1.5
+      tmpdepfile3=$dir.libs/$base.o.d    # libtool 1.5
+      tmpdepfile4=$dir.libs/$base.d      # Compaq CCC V6.2-504
+      "$@" -Wc,-MD
+   else
+      tmpdepfile1=$dir$base.o.d
+      tmpdepfile2=$dir$base.d
+      tmpdepfile3=$dir$base.d
+      tmpdepfile4=$dir$base.d
+      "$@" -MD
+   fi
+
+   stat=$?
+   if test $stat -eq 0; then :
+   else
+      rm -f "$tmpdepfile1" "$tmpdepfile2" "$tmpdepfile3" "$tmpdepfile4"
+      exit $stat
+   fi
+
+   for tmpdepfile in "$tmpdepfile1" "$tmpdepfile2" "$tmpdepfile3" "$tmpdepfile4"
+   do
+     test -f "$tmpdepfile" && break
+   done
+   if test -f "$tmpdepfile"; then
+      sed -e "s,^.*\.[a-z]*:,$object:," < "$tmpdepfile" > "$depfile"
+      # That's a tab and a space in the [].
+      sed -e 's,^.*\.[a-z]*:[	 ]*,,' -e 's,$,:,' < "$tmpdepfile" >> "$depfile"
+   else
+      echo "#dummy" > "$depfile"
+   fi
+   rm -f "$tmpdepfile"
+   ;;
+
+#nosideeffect)
+  # This comment above is used by automake to tell side-effect
+  # dependency tracking mechanisms from slower ones.
+
+dashmstdout)
+  # Important note: in order to support this mode, a compiler *must*
+  # always write the preprocessed file to stdout, regardless of -o.
+  "$@" || exit $?
+
+  # Remove the call to Libtool.
+  if test "$libtool" = yes; then
+    while test $1 != '--mode=compile'; do
+      shift
+    done
+    shift
+  fi
+
+  # Remove `-o $object'.
+  IFS=" "
+  for arg
+  do
+    case $arg in
+    -o)
+      shift
+      ;;
+    $object)
+      shift
+      ;;
+    *)
+      set fnord "$@" "$arg"
+      shift # fnord
+      shift # $arg
+      ;;
+    esac
+  done
+
+  test -z "$dashmflag" && dashmflag=-M
+  # Require at least two characters before searching for `:'
+  # in the target name.  This is to cope with DOS-style filenames:
+  # a dependency such as `c:/foo/bar' could be seen as target `c' otherwise.
+  "$@" $dashmflag |
+    sed 's:^[  ]*[^: ][^:][^:]*\:[    ]*:'"$object"'\: :' > "$tmpdepfile"
+  rm -f "$depfile"
+  cat < "$tmpdepfile" > "$depfile"
+  tr ' ' '
+' < "$tmpdepfile" | \
+## Some versions of the HPUX 10.20 sed can't process this invocation
+## correctly.  Breaking it into two sed invocations is a workaround.
+    sed -e 's/^\\$//' -e '/^$/d' -e '/:$/d' | sed -e 's/$/ :/' >> "$depfile"
+  rm -f "$tmpdepfile"
+  ;;
+
+dashXmstdout)
+  # This case only exists to satisfy depend.m4.  It is never actually
+  # run, as this mode is specially recognized in the preamble.
+  exit 1
+  ;;
+
+makedepend)
+  "$@" || exit $?
+  # Remove any Libtool call
+  if test "$libtool" = yes; then
+    while test $1 != '--mode=compile'; do
+      shift
+    done
+    shift
+  fi
+  # X makedepend
+  shift
+  cleared=no
+  for arg in "$@"; do
+    case $cleared in
+    no)
+      set ""; shift
+      cleared=yes ;;
+    esac
+    case "$arg" in
+    -D*|-I*)
+      set fnord "$@" "$arg"; shift ;;
+    # Strip any option that makedepend may not understand.  Remove
+    # the object too, otherwise makedepend will parse it as a source file.
+    -*|$object)
+      ;;
+    *)
+      set fnord "$@" "$arg"; shift ;;
+    esac
+  done
+  obj_suffix="`echo $object | sed 's/^.*\././'`"
+  touch "$tmpdepfile"
+  ${MAKEDEPEND-makedepend} -o"$obj_suffix" -f"$tmpdepfile" "$@"
+  rm -f "$depfile"
+  cat < "$tmpdepfile" > "$depfile"
+  sed '1,2d' "$tmpdepfile" | tr ' ' '
+' | \
+## Some versions of the HPUX 10.20 sed can't process this invocation
+## correctly.  Breaking it into two sed invocations is a workaround.
+    sed -e 's/^\\$//' -e '/^$/d' -e '/:$/d' | sed -e 's/$/ :/' >> "$depfile"
+  rm -f "$tmpdepfile" "$tmpdepfile".bak
+  ;;
+
+cpp)
+  # Important note: in order to support this mode, a compiler *must*
+  # always write the preprocessed file to stdout.
+  "$@" || exit $?
+
+  # Remove the call to Libtool.
+  if test "$libtool" = yes; then
+    while test $1 != '--mode=compile'; do
+      shift
+    done
+    shift
+  fi
+
+  # Remove `-o $object'.
+  IFS=" "
+  for arg
+  do
+    case $arg in
+    -o)
+      shift
+      ;;
+    $object)
+      shift
+      ;;
+    *)
+      set fnord "$@" "$arg"
+      shift # fnord
+      shift # $arg
+      ;;
+    esac
+  done
+
+  "$@" -E |
+    sed -n '/^# [0-9][0-9]* "\([^"]*\)".*/ s:: \1 \\:p' |
+    sed '$ s: \\$::' > "$tmpdepfile"
+  rm -f "$depfile"
+  echo "$object : \\" > "$depfile"
+  cat < "$tmpdepfile" >> "$depfile"
+  sed < "$tmpdepfile" '/^$/d;s/^ //;s/ \\$//;s/$/ :/' >> "$depfile"
+  rm -f "$tmpdepfile"
+  ;;
+
+msvisualcpp)
+  # Important note: in order to support this mode, a compiler *must*
+  # always write the preprocessed file to stdout, regardless of -o,
+  # because we must use -o when running libtool.
+  "$@" || exit $?
+  IFS=" "
+  for arg
+  do
+    case "$arg" in
+    "-Gm"|"/Gm"|"-Gi"|"/Gi"|"-ZI"|"/ZI")
+	set fnord "$@"
+	shift
+	shift
+	;;
+    *)
+	set fnord "$@" "$arg"
+	shift
+	shift
+	;;
+    esac
+  done
+  "$@" -E |
+  sed -n '/^#line [0-9][0-9]* "\([^"]*\)"/ s::echo "`cygpath -u \\"\1\\"`":p' | sort | uniq > "$tmpdepfile"
+  rm -f "$depfile"
+  echo "$object : \\" > "$depfile"
+  . "$tmpdepfile" | sed 's% %\\ %g' | sed -n '/^\(.*\)$/ s::	\1 \\:p' >> "$depfile"
+  echo "	" >> "$depfile"
+  . "$tmpdepfile" | sed 's% %\\ %g' | sed -n '/^\(.*\)$/ s::\1\::p' >> "$depfile"
+  rm -f "$tmpdepfile"
+  ;;
+
+none)
+  exec "$@"
+  ;;
+
+*)
+  echo "Unknown depmode $depmode" 1>&2
+  exit 1
+  ;;
+esac
+
+exit 0
+
+# Local Variables:
+# mode: shell-script
+# sh-indentation: 2
+# eval: (add-hook 'write-file-hooks 'time-stamp)
+# time-stamp-start: "scriptversion="
+# time-stamp-format: "%:y-%02m-%02d.%02H"
+# time-stamp-end: "$"
+# End:
diff --git a/libevent/devpoll.c b/libevent/devpoll.c
new file mode 100644
index 0000000..cbd2730
--- /dev/null
+++ b/libevent/devpoll.c
@@ -0,0 +1,417 @@
+/*
+ * Copyright 2000-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <sys/types.h>
+#include <sys/resource.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#include <sys/queue.h>
+#include <sys/devpoll.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <fcntl.h>
+#include <errno.h>
+#include <assert.h>
+
+#include "event.h"
+#include "event-internal.h"
+#include "evsignal.h"
+#include "log.h"
+
+/* due to limitations in the devpoll interface, we need to keep track of
+ * all file descriptors outself.
+ */
+struct evdevpoll {
+	struct event *evread;
+	struct event *evwrite;
+};
+
+struct devpollop {
+	struct evdevpoll *fds;
+	int nfds;
+	struct pollfd *events;
+	int nevents;
+	int dpfd;
+	struct pollfd *changes;
+	int nchanges;
+};
+
+static void *devpoll_init	(struct event_base *);
+static int devpoll_add	(void *, struct event *);
+static int devpoll_del	(void *, struct event *);
+static int devpoll_dispatch	(struct event_base *, void *, struct timeval *);
+static void devpoll_dealloc	(struct event_base *, void *);
+
+const struct eventop devpollops = {
+	"devpoll",
+	devpoll_init,
+	devpoll_add,
+	devpoll_del,
+	devpoll_dispatch,
+	devpoll_dealloc,
+	1 /* need reinit */
+};
+
+#define NEVENT	32000
+
+static int
+devpoll_commit(struct devpollop *devpollop)
+{
+	/*
+	 * Due to a bug in Solaris, we have to use pwrite with an offset of 0.
+	 * Write is limited to 2GB of data, until it will fail.
+	 */
+	if (pwrite(devpollop->dpfd, devpollop->changes,
+		sizeof(struct pollfd) * devpollop->nchanges, 0) == -1)
+		return(-1);
+
+	devpollop->nchanges = 0;
+	return(0);
+}
+
+static int
+devpoll_queue(struct devpollop *devpollop, int fd, int events) {
+	struct pollfd *pfd;
+
+	if (devpollop->nchanges >= devpollop->nevents) {
+		/*
+		 * Change buffer is full, must commit it to /dev/poll before 
+		 * adding more 
+		 */
+		if (devpoll_commit(devpollop) != 0)
+			return(-1);
+	}
+
+	pfd = &devpollop->changes[devpollop->nchanges++];
+	pfd->fd = fd;
+	pfd->events = events;
+	pfd->revents = 0;
+
+	return(0);
+}
+
+static void *
+devpoll_init(struct event_base *base)
+{
+	int dpfd, nfiles = NEVENT;
+	struct rlimit rl;
+	struct devpollop *devpollop;
+
+	/* Disable devpoll when this environment variable is set */
+	if (getenv("EVENT_NODEVPOLL"))
+		return (NULL);
+
+	if (!(devpollop = calloc(1, sizeof(struct devpollop))))
+		return (NULL);
+
+	if (getrlimit(RLIMIT_NOFILE, &rl) == 0 &&
+	    rl.rlim_cur != RLIM_INFINITY)
+		nfiles = rl.rlim_cur;
+
+	/* Initialize the kernel queue */
+	if ((dpfd = open("/dev/poll", O_RDWR)) == -1) {
+                event_warn("open: /dev/poll");
+		free(devpollop);
+		return (NULL);
+	}
+
+	devpollop->dpfd = dpfd;
+
+	/* Initialize fields */
+	devpollop->events = calloc(nfiles, sizeof(struct pollfd));
+	if (devpollop->events == NULL) {
+		free(devpollop);
+		close(dpfd);
+		return (NULL);
+	}
+	devpollop->nevents = nfiles;
+
+	devpollop->fds = calloc(nfiles, sizeof(struct evdevpoll));
+	if (devpollop->fds == NULL) {
+		free(devpollop->events);
+		free(devpollop);
+		close(dpfd);
+		return (NULL);
+	}
+	devpollop->nfds = nfiles;
+
+	devpollop->changes = calloc(nfiles, sizeof(struct pollfd));
+	if (devpollop->changes == NULL) {
+		free(devpollop->fds);
+		free(devpollop->events);
+		free(devpollop);
+		close(dpfd);
+		return (NULL);
+	}
+
+	evsignal_init(base);
+
+	return (devpollop);
+}
+
+static int
+devpoll_recalc(struct event_base *base, void *arg, int max)
+{
+	struct devpollop *devpollop = arg;
+
+	if (max >= devpollop->nfds) {
+		struct evdevpoll *fds;
+		int nfds;
+
+		nfds = devpollop->nfds;
+		while (nfds <= max)
+			nfds <<= 1;
+
+		fds = realloc(devpollop->fds, nfds * sizeof(struct evdevpoll));
+		if (fds == NULL) {
+			event_warn("realloc");
+			return (-1);
+		}
+		devpollop->fds = fds;
+		memset(fds + devpollop->nfds, 0,
+		    (nfds - devpollop->nfds) * sizeof(struct evdevpoll));
+		devpollop->nfds = nfds;
+	}
+
+	return (0);
+}
+
+static int
+devpoll_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	struct devpollop *devpollop = arg;
+	struct pollfd *events = devpollop->events;
+	struct dvpoll dvp;
+	struct evdevpoll *evdp;
+	int i, res, timeout = -1;
+
+	if (devpollop->nchanges)
+		devpoll_commit(devpollop);
+
+	if (tv != NULL)
+		timeout = tv->tv_sec * 1000 + (tv->tv_usec + 999) / 1000;
+
+	dvp.dp_fds = devpollop->events;
+	dvp.dp_nfds = devpollop->nevents;
+	dvp.dp_timeout = timeout;
+
+	res = ioctl(devpollop->dpfd, DP_POLL, &dvp);
+
+	if (res == -1) {
+		if (errno != EINTR) {
+			event_warn("ioctl: DP_POLL");
+			return (-1);
+		}
+
+		evsignal_process(base);
+		return (0);
+	} else if (base->sig.evsignal_caught) {
+		evsignal_process(base);
+	}
+
+	event_debug(("%s: devpoll_wait reports %d", __func__, res));
+
+	for (i = 0; i < res; i++) {
+		int which = 0;
+		int what = events[i].revents;
+		struct event *evread = NULL, *evwrite = NULL;
+
+		assert(events[i].fd < devpollop->nfds);
+		evdp = &devpollop->fds[events[i].fd];
+   
+                if (what & POLLHUP)
+                        what |= POLLIN | POLLOUT;
+                else if (what & POLLERR)
+                        what |= POLLIN | POLLOUT;
+
+		if (what & POLLIN) {
+			evread = evdp->evread;
+			which |= EV_READ;
+		}
+
+		if (what & POLLOUT) {
+			evwrite = evdp->evwrite;
+			which |= EV_WRITE;
+		}
+
+		if (!which)
+			continue;
+
+		if (evread != NULL && !(evread->ev_events & EV_PERSIST))
+			event_del(evread);
+		if (evwrite != NULL && evwrite != evread &&
+		    !(evwrite->ev_events & EV_PERSIST))
+			event_del(evwrite);
+
+		if (evread != NULL)
+			event_active(evread, EV_READ, 1);
+		if (evwrite != NULL)
+			event_active(evwrite, EV_WRITE, 1);
+	}
+
+	return (0);
+}
+
+
+static int
+devpoll_add(void *arg, struct event *ev)
+{
+	struct devpollop *devpollop = arg;
+	struct evdevpoll *evdp;
+	int fd, events;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_add(ev));
+
+	fd = ev->ev_fd;
+	if (fd >= devpollop->nfds) {
+		/* Extend the file descriptor array as necessary */
+		if (devpoll_recalc(ev->ev_base, devpollop, fd) == -1)
+			return (-1);
+	}
+	evdp = &devpollop->fds[fd];
+
+	/* 
+	 * It's not necessary to OR the existing read/write events that we
+	 * are currently interested in with the new event we are adding.
+	 * The /dev/poll driver ORs any new events with the existing events
+	 * that it has cached for the fd.
+	 */
+
+	events = 0;
+	if (ev->ev_events & EV_READ) {
+		if (evdp->evread && evdp->evread != ev) {
+		   /* There is already a different read event registered */
+		   return(-1);
+		}
+		events |= POLLIN;
+	}
+
+	if (ev->ev_events & EV_WRITE) {
+		if (evdp->evwrite && evdp->evwrite != ev) {
+		   /* There is already a different write event registered */
+		   return(-1);
+		}
+		events |= POLLOUT;
+	}
+
+	if (devpoll_queue(devpollop, fd, events) != 0)
+		return(-1);
+
+	/* Update events responsible */
+	if (ev->ev_events & EV_READ)
+		evdp->evread = ev;
+	if (ev->ev_events & EV_WRITE)
+		evdp->evwrite = ev;
+
+	return (0);
+}
+
+static int
+devpoll_del(void *arg, struct event *ev)
+{
+	struct devpollop *devpollop = arg;
+	struct evdevpoll *evdp;
+	int fd, events;
+	int needwritedelete = 1, needreaddelete = 1;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_del(ev));
+
+	fd = ev->ev_fd;
+	if (fd >= devpollop->nfds)
+		return (0);
+	evdp = &devpollop->fds[fd];
+
+	events = 0;
+	if (ev->ev_events & EV_READ)
+		events |= POLLIN;
+	if (ev->ev_events & EV_WRITE)
+		events |= POLLOUT;
+
+	/*
+	 * The only way to remove an fd from the /dev/poll monitored set is
+	 * to use POLLREMOVE by itself.  This removes ALL events for the fd 
+	 * provided so if we care about two events and are only removing one 
+	 * we must re-add the other event after POLLREMOVE.
+	 */
+
+	if (devpoll_queue(devpollop, fd, POLLREMOVE) != 0)
+		return(-1);
+
+	if ((events & (POLLIN|POLLOUT)) != (POLLIN|POLLOUT)) {
+		/*
+		 * We're not deleting all events, so we must resubmit the
+		 * event that we are still interested in if one exists.
+		 */
+
+		if ((events & POLLIN) && evdp->evwrite != NULL) {
+			/* Deleting read, still care about write */
+			devpoll_queue(devpollop, fd, POLLOUT);
+			needwritedelete = 0;
+		} else if ((events & POLLOUT) && evdp->evread != NULL) {
+			/* Deleting write, still care about read */
+			devpoll_queue(devpollop, fd, POLLIN);
+			needreaddelete = 0;
+		}
+	}
+
+	if (needreaddelete)
+		evdp->evread = NULL;
+	if (needwritedelete)
+		evdp->evwrite = NULL;
+
+	return (0);
+}
+
+static void
+devpoll_dealloc(struct event_base *base, void *arg)
+{
+	struct devpollop *devpollop = arg;
+
+	evsignal_dealloc(base);
+	if (devpollop->fds)
+		free(devpollop->fds);
+	if (devpollop->events)
+		free(devpollop->events);
+	if (devpollop->changes)
+		free(devpollop->changes);
+	if (devpollop->dpfd >= 0)
+		close(devpollop->dpfd);
+
+	memset(devpollop, 0, sizeof(struct devpollop));
+	free(devpollop);
+}
diff --git a/libevent/epoll.c b/libevent/epoll.c
new file mode 100644
index 0000000..cf3c859
--- /dev/null
+++ b/libevent/epoll.c
@@ -0,0 +1,370 @@
+/*
+ * Copyright 2000-2003 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <stdint.h>
+#include <sys/types.h>
+#include <sys/resource.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#include <sys/queue.h>
+#include <sys/epoll.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <errno.h>
+#ifdef HAVE_FCNTL_H
+#include <fcntl.h>
+#endif
+
+#include "event.h"
+#include "event-internal.h"
+#include "evsignal.h"
+#include "log.h"
+
+/* due to limitations in the epoll interface, we need to keep track of
+ * all file descriptors outself.
+ */
+struct evepoll {
+	struct event *evread;
+	struct event *evwrite;
+};
+
+struct epollop {
+	struct evepoll *fds;
+	int nfds;
+	struct epoll_event *events;
+	int nevents;
+	int epfd;
+};
+
+static void *epoll_init	(struct event_base *);
+static int epoll_add	(void *, struct event *);
+static int epoll_del	(void *, struct event *);
+static int epoll_dispatch	(struct event_base *, void *, struct timeval *);
+static void epoll_dealloc	(struct event_base *, void *);
+
+const struct eventop epollops = {
+	"epoll",
+	epoll_init,
+	epoll_add,
+	epoll_del,
+	epoll_dispatch,
+	epoll_dealloc,
+	1 /* need reinit */
+};
+
+#ifdef HAVE_SETFD
+#define FD_CLOSEONEXEC(x) do { \
+        if (fcntl(x, F_SETFD, 1) == -1) \
+                event_warn("fcntl(%d, F_SETFD)", x); \
+} while (0)
+#else
+#define FD_CLOSEONEXEC(x)
+#endif
+
+#define NEVENT	32000
+
+/* On Linux kernels at least up to 2.6.24.4, epoll can't handle timeout
+ * values bigger than (LONG_MAX - 999ULL)/HZ.  HZ in the wild can be
+ * as big as 1000, and LONG_MAX can be as small as (1<<31)-1, so the
+ * largest number of msec we can support here is 2147482.  Let's
+ * round that down by 47 seconds.
+ */
+#define MAX_EPOLL_TIMEOUT_MSEC (35*60*1000)
+
+static void *
+epoll_init(struct event_base *base)
+{
+	int epfd, nfiles = NEVENT;
+	struct rlimit rl;
+	struct epollop *epollop;
+
+	/* Disable epollueue when this environment variable is set */
+	if (getenv("EVENT_NOEPOLL"))
+		return (NULL);
+
+	if (getrlimit(RLIMIT_NOFILE, &rl) == 0 &&
+	    rl.rlim_cur != RLIM_INFINITY) {
+		/*
+		 * Solaris is somewhat retarded - it's important to drop
+		 * backwards compatibility when making changes.  So, don't
+		 * dare to put rl.rlim_cur here.
+		 */
+		nfiles = rl.rlim_cur - 1;
+	}
+
+	/* Initalize the kernel queue */
+
+	if ((epfd = epoll_create(nfiles)) == -1) {
+		if (errno != ENOSYS)
+			event_warn("epoll_create");
+		return (NULL);
+	}
+
+	FD_CLOSEONEXEC(epfd);
+
+	if (!(epollop = calloc(1, sizeof(struct epollop))))
+		return (NULL);
+
+	epollop->epfd = epfd;
+
+	/* Initalize fields */
+	epollop->events = malloc(nfiles * sizeof(struct epoll_event));
+	if (epollop->events == NULL) {
+		free(epollop);
+		return (NULL);
+	}
+	epollop->nevents = nfiles;
+
+	epollop->fds = calloc(nfiles, sizeof(struct evepoll));
+	if (epollop->fds == NULL) {
+		free(epollop->events);
+		free(epollop);
+		return (NULL);
+	}
+	epollop->nfds = nfiles;
+
+	evsignal_init(base);
+
+	return (epollop);
+}
+
+static int
+epoll_recalc(struct event_base *base, void *arg, int max)
+{
+	struct epollop *epollop = arg;
+
+	if (max > epollop->nfds) {
+		struct evepoll *fds;
+		int nfds;
+
+		nfds = epollop->nfds;
+		while (nfds < max)
+			nfds <<= 1;
+
+		fds = realloc(epollop->fds, nfds * sizeof(struct evepoll));
+		if (fds == NULL) {
+			event_warn("realloc");
+			return (-1);
+		}
+		epollop->fds = fds;
+		memset(fds + epollop->nfds, 0,
+		    (nfds - epollop->nfds) * sizeof(struct evepoll));
+		epollop->nfds = nfds;
+	}
+
+	return (0);
+}
+
+static int
+epoll_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	struct epollop *epollop = arg;
+	struct epoll_event *events = epollop->events;
+	struct evepoll *evep;
+	int i, res, timeout = -1;
+
+	if (tv != NULL)
+		timeout = tv->tv_sec * 1000 + (tv->tv_usec + 999) / 1000;
+
+	if (timeout > MAX_EPOLL_TIMEOUT_MSEC) {
+		/* Linux kernels can wait forever if the timeout is too big;
+		 * see comment on MAX_EPOLL_TIMEOUT_MSEC. */
+		timeout = MAX_EPOLL_TIMEOUT_MSEC;
+	}
+
+	res = epoll_wait(epollop->epfd, events, epollop->nevents, timeout);
+
+	if (res == -1) {
+		if (errno != EINTR) {
+			event_warn("epoll_wait");
+			return (-1);
+		}
+
+		evsignal_process(base);
+		return (0);
+	} else if (base->sig.evsignal_caught) {
+		evsignal_process(base);
+	}
+
+	event_debug(("%s: epoll_wait reports %d", __func__, res));
+
+	for (i = 0; i < res; i++) {
+		int what = events[i].events;
+		struct event *evread = NULL, *evwrite = NULL;
+
+		evep = (struct evepoll *)events[i].data.ptr;
+
+		if (what & (EPOLLHUP|EPOLLERR)) {
+			evread = evep->evread;
+			evwrite = evep->evwrite;
+		} else {
+			if (what & EPOLLIN) {
+				evread = evep->evread;
+			}
+
+			if (what & EPOLLOUT) {
+				evwrite = evep->evwrite;
+			}
+		}
+
+		if (!(evread||evwrite))
+			continue;
+
+		if (evread != NULL)
+			event_active(evread, EV_READ, 1);
+		if (evwrite != NULL)
+			event_active(evwrite, EV_WRITE, 1);
+	}
+
+	return (0);
+}
+
+
+static int
+epoll_add(void *arg, struct event *ev)
+{
+	struct epollop *epollop = arg;
+	struct epoll_event epev = {0, {0}};
+	struct evepoll *evep;
+	int fd, op, events;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_add(ev));
+
+	fd = ev->ev_fd;
+	if (fd >= epollop->nfds) {
+		/* Extent the file descriptor array as necessary */
+		if (epoll_recalc(ev->ev_base, epollop, fd) == -1)
+			return (-1);
+	}
+	evep = &epollop->fds[fd];
+	op = EPOLL_CTL_ADD;
+	events = 0;
+	if (evep->evread != NULL) {
+		events |= EPOLLIN;
+		op = EPOLL_CTL_MOD;
+	}
+	if (evep->evwrite != NULL) {
+		events |= EPOLLOUT;
+		op = EPOLL_CTL_MOD;
+	}
+
+	if (ev->ev_events & EV_READ)
+		events |= EPOLLIN;
+	if (ev->ev_events & EV_WRITE)
+		events |= EPOLLOUT;
+
+	epev.data.ptr = evep;
+	epev.events = events;
+	if (epoll_ctl(epollop->epfd, op, ev->ev_fd, &epev) == -1)
+			return (-1);
+
+	/* Update events responsible */
+	if (ev->ev_events & EV_READ)
+		evep->evread = ev;
+	if (ev->ev_events & EV_WRITE)
+		evep->evwrite = ev;
+
+	return (0);
+}
+
+static int
+epoll_del(void *arg, struct event *ev)
+{
+	struct epollop *epollop = arg;
+	struct epoll_event epev = {0, {0}};
+	struct evepoll *evep;
+	int fd, events, op;
+	int needwritedelete = 1, needreaddelete = 1;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_del(ev));
+
+	fd = ev->ev_fd;
+	if (fd >= epollop->nfds)
+		return (0);
+	evep = &epollop->fds[fd];
+
+	op = EPOLL_CTL_DEL;
+	events = 0;
+
+	if (ev->ev_events & EV_READ)
+		events |= EPOLLIN;
+	if (ev->ev_events & EV_WRITE)
+		events |= EPOLLOUT;
+
+	if ((events & (EPOLLIN|EPOLLOUT)) != (EPOLLIN|EPOLLOUT)) {
+		if ((events & EPOLLIN) && evep->evwrite != NULL) {
+			needwritedelete = 0;
+			events = EPOLLOUT;
+			op = EPOLL_CTL_MOD;
+		} else if ((events & EPOLLOUT) && evep->evread != NULL) {
+			needreaddelete = 0;
+			events = EPOLLIN;
+			op = EPOLL_CTL_MOD;
+		}
+	}
+
+	epev.events = events;
+	epev.data.ptr = evep;
+
+	if (needreaddelete)
+		evep->evread = NULL;
+	if (needwritedelete)
+		evep->evwrite = NULL;
+
+	if (epoll_ctl(epollop->epfd, op, fd, &epev) == -1)
+		return (-1);
+
+	return (0);
+}
+
+static void
+epoll_dealloc(struct event_base *base, void *arg)
+{
+	struct epollop *epollop = arg;
+
+	evsignal_dealloc(base);
+	if (epollop->fds)
+		free(epollop->fds);
+	if (epollop->events)
+		free(epollop->events);
+	if (epollop->epfd >= 0)
+		close(epollop->epfd);
+
+	memset(epollop, 0, sizeof(struct epollop));
+	free(epollop);
+}
diff --git a/libevent/epoll_sub.c b/libevent/epoll_sub.c
new file mode 100644
index 0000000..431970c
--- /dev/null
+++ b/libevent/epoll_sub.c
@@ -0,0 +1,52 @@
+/*
+ * Copyright 2003 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#include <stdint.h>
+
+#include <sys/param.h>
+#include <sys/types.h>
+#include <sys/syscall.h>
+#include <sys/epoll.h>
+#include <unistd.h>
+
+int
+epoll_create(int size)
+{
+	return (syscall(__NR_epoll_create, size));
+}
+
+int
+epoll_ctl(int epfd, int op, int fd, struct epoll_event *event)
+{
+
+	return (syscall(__NR_epoll_ctl, epfd, op, fd, event));
+}
+
+int
+epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout)
+{
+	return (syscall(__NR_epoll_wait, epfd, events, maxevents, timeout));
+}
diff --git a/libevent/evbuffer.c b/libevent/evbuffer.c
new file mode 100644
index 0000000..f2179a5
--- /dev/null
+++ b/libevent/evbuffer.c
@@ -0,0 +1,455 @@
+/*
+ * Copyright (c) 2002-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#include <sys/types.h>
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+
+#include <errno.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#ifdef HAVE_STDARG_H
+#include <stdarg.h>
+#endif
+
+#ifdef WIN32
+#include <winsock2.h>
+#endif
+
+#include "evutil.h"
+#include "event.h"
+
+/* prototypes */
+
+void bufferevent_read_pressure_cb(struct evbuffer *, size_t, size_t, void *);
+
+static int
+bufferevent_add(struct event *ev, int timeout)
+{
+	struct timeval tv, *ptv = NULL;
+
+	if (timeout) {
+		evutil_timerclear(&tv);
+		tv.tv_sec = timeout;
+		ptv = &tv;
+	}
+
+	return (event_add(ev, ptv));
+}
+
+/* 
+ * This callback is executed when the size of the input buffer changes.
+ * We use it to apply back pressure on the reading side.
+ */
+
+void
+bufferevent_read_pressure_cb(struct evbuffer *buf, size_t old, size_t now,
+    void *arg) {
+	struct bufferevent *bufev = arg;
+	/* 
+	 * If we are below the watermark then reschedule reading if it's
+	 * still enabled.
+	 */
+	if (bufev->wm_read.high == 0 || now < bufev->wm_read.high) {
+		evbuffer_setcb(buf, NULL, NULL);
+
+		if (bufev->enabled & EV_READ)
+			bufferevent_add(&bufev->ev_read, bufev->timeout_read);
+	}
+}
+
+static void
+bufferevent_readcb(int fd, short event, void *arg)
+{
+	struct bufferevent *bufev = arg;
+	int res = 0;
+	short what = EVBUFFER_READ;
+	size_t len;
+	int howmuch = -1;
+
+	if (event == EV_TIMEOUT) {
+		what |= EVBUFFER_TIMEOUT;
+		goto error;
+	}
+
+	/*
+	 * If we have a high watermark configured then we don't want to
+	 * read more data than would make us reach the watermark.
+	 */
+	if (bufev->wm_read.high != 0) {
+		howmuch = bufev->wm_read.high - EVBUFFER_LENGTH(bufev->input);
+		/* we might have lowered the watermark, stop reading */
+		if (howmuch <= 0) {
+			struct evbuffer *buf = bufev->input;
+			event_del(&bufev->ev_read);
+			evbuffer_setcb(buf,
+			    bufferevent_read_pressure_cb, bufev);
+			return;
+		}
+	}
+
+	res = evbuffer_read(bufev->input, fd, howmuch);
+	if (res == -1) {
+		if (errno == EAGAIN || errno == EINTR)
+			goto reschedule;
+		/* error case */
+		what |= EVBUFFER_ERROR;
+	} else if (res == 0) {
+		/* eof case */
+		what |= EVBUFFER_EOF;
+	}
+
+	if (res <= 0)
+		goto error;
+
+	bufferevent_add(&bufev->ev_read, bufev->timeout_read);
+
+	/* See if this callbacks meets the water marks */
+	len = EVBUFFER_LENGTH(bufev->input);
+	if (bufev->wm_read.low != 0 && len < bufev->wm_read.low)
+		return;
+	if (bufev->wm_read.high != 0 && len >= bufev->wm_read.high) {
+		struct evbuffer *buf = bufev->input;
+		event_del(&bufev->ev_read);
+
+		/* Now schedule a callback for us when the buffer changes */
+		evbuffer_setcb(buf, bufferevent_read_pressure_cb, bufev);
+	}
+
+	/* Invoke the user callback - must always be called last */
+	if (bufev->readcb != NULL)
+		(*bufev->readcb)(bufev, bufev->cbarg);
+	return;
+
+ reschedule:
+	bufferevent_add(&bufev->ev_read, bufev->timeout_read);
+	return;
+
+ error:
+	(*bufev->errorcb)(bufev, what, bufev->cbarg);
+}
+
+static void
+bufferevent_writecb(int fd, short event, void *arg)
+{
+	struct bufferevent *bufev = arg;
+	int res = 0;
+	short what = EVBUFFER_WRITE;
+
+	if (event == EV_TIMEOUT) {
+		what |= EVBUFFER_TIMEOUT;
+		goto error;
+	}
+
+	if (EVBUFFER_LENGTH(bufev->output)) {
+	    res = evbuffer_write(bufev->output, fd);
+	    if (res == -1) {
+#ifndef WIN32
+/*todo. evbuffer uses WriteFile when WIN32 is set. WIN32 system calls do not
+ *set errno. thus this error checking is not portable*/
+		    if (errno == EAGAIN ||
+			errno == EINTR ||
+			errno == EINPROGRESS)
+			    goto reschedule;
+		    /* error case */
+		    what |= EVBUFFER_ERROR;
+
+#else
+				goto reschedule;
+#endif
+
+	    } else if (res == 0) {
+		    /* eof case */
+		    what |= EVBUFFER_EOF;
+	    }
+	    if (res <= 0)
+		    goto error;
+	}
+
+	if (EVBUFFER_LENGTH(bufev->output) != 0)
+		bufferevent_add(&bufev->ev_write, bufev->timeout_write);
+
+	/*
+	 * Invoke the user callback if our buffer is drained or below the
+	 * low watermark.
+	 */
+	if (bufev->writecb != NULL &&
+	    EVBUFFER_LENGTH(bufev->output) <= bufev->wm_write.low)
+		(*bufev->writecb)(bufev, bufev->cbarg);
+
+	return;
+
+ reschedule:
+	if (EVBUFFER_LENGTH(bufev->output) != 0)
+		bufferevent_add(&bufev->ev_write, bufev->timeout_write);
+	return;
+
+ error:
+	(*bufev->errorcb)(bufev, what, bufev->cbarg);
+}
+
+/*
+ * Create a new buffered event object.
+ *
+ * The read callback is invoked whenever we read new data.
+ * The write callback is invoked whenever the output buffer is drained.
+ * The error callback is invoked on a write/read error or on EOF.
+ *
+ * Both read and write callbacks maybe NULL.  The error callback is not
+ * allowed to be NULL and have to be provided always.
+ */
+
+struct bufferevent *
+bufferevent_new(int fd, evbuffercb readcb, evbuffercb writecb,
+    everrorcb errorcb, void *cbarg)
+{
+	struct bufferevent *bufev;
+
+	if ((bufev = calloc(1, sizeof(struct bufferevent))) == NULL)
+		return (NULL);
+
+	if ((bufev->input = evbuffer_new()) == NULL) {
+		free(bufev);
+		return (NULL);
+	}
+
+	if ((bufev->output = evbuffer_new()) == NULL) {
+		evbuffer_free(bufev->input);
+		free(bufev);
+		return (NULL);
+	}
+
+	event_set(&bufev->ev_read, fd, EV_READ, bufferevent_readcb, bufev);
+	event_set(&bufev->ev_write, fd, EV_WRITE, bufferevent_writecb, bufev);
+
+	bufferevent_setcb(bufev, readcb, writecb, errorcb, cbarg);
+
+	/*
+	 * Set to EV_WRITE so that using bufferevent_write is going to
+	 * trigger a callback.  Reading needs to be explicitly enabled
+	 * because otherwise no data will be available.
+	 */
+	bufev->enabled = EV_WRITE;
+
+	return (bufev);
+}
+
+void
+bufferevent_setcb(struct bufferevent *bufev,
+    evbuffercb readcb, evbuffercb writecb, everrorcb errorcb, void *cbarg)
+{
+	bufev->readcb = readcb;
+	bufev->writecb = writecb;
+	bufev->errorcb = errorcb;
+
+	bufev->cbarg = cbarg;
+}
+
+void
+bufferevent_setfd(struct bufferevent *bufev, int fd)
+{
+	event_del(&bufev->ev_read);
+	event_del(&bufev->ev_write);
+
+	event_set(&bufev->ev_read, fd, EV_READ, bufferevent_readcb, bufev);
+	event_set(&bufev->ev_write, fd, EV_WRITE, bufferevent_writecb, bufev);
+	if (bufev->ev_base != NULL) {
+		event_base_set(bufev->ev_base, &bufev->ev_read);
+		event_base_set(bufev->ev_base, &bufev->ev_write);
+	}
+
+	/* might have to manually trigger event registration */
+}
+
+int
+bufferevent_priority_set(struct bufferevent *bufev, int priority)
+{
+	if (event_priority_set(&bufev->ev_read, priority) == -1)
+		return (-1);
+	if (event_priority_set(&bufev->ev_write, priority) == -1)
+		return (-1);
+
+	return (0);
+}
+
+/* Closing the file descriptor is the responsibility of the caller */
+
+void
+bufferevent_free(struct bufferevent *bufev)
+{
+	event_del(&bufev->ev_read);
+	event_del(&bufev->ev_write);
+
+	evbuffer_free(bufev->input);
+	evbuffer_free(bufev->output);
+
+	free(bufev);
+}
+
+/*
+ * Returns 0 on success;
+ *        -1 on failure.
+ */
+
+int
+bufferevent_write(struct bufferevent *bufev, const void *data, size_t size)
+{
+	int res;
+
+	res = evbuffer_add(bufev->output, data, size);
+
+	if (res == -1)
+		return (res);
+
+	/* If everything is okay, we need to schedule a write */
+	if (size > 0 && (bufev->enabled & EV_WRITE))
+		bufferevent_add(&bufev->ev_write, bufev->timeout_write);
+
+	return (res);
+}
+
+int
+bufferevent_write_buffer(struct bufferevent *bufev, struct evbuffer *buf)
+{
+	int res;
+
+	res = bufferevent_write(bufev, buf->buffer, buf->off);
+	if (res != -1)
+		evbuffer_drain(buf, buf->off);
+
+	return (res);
+}
+
+size_t
+bufferevent_read(struct bufferevent *bufev, void *data, size_t size)
+{
+	struct evbuffer *buf = bufev->input;
+
+	if (buf->off < size)
+		size = buf->off;
+
+	/* Copy the available data to the user buffer */
+	memcpy(data, buf->buffer, size);
+
+	if (size)
+		evbuffer_drain(buf, size);
+
+	return (size);
+}
+
+int
+bufferevent_enable(struct bufferevent *bufev, short event)
+{
+	if (event & EV_READ) {
+		if (bufferevent_add(&bufev->ev_read, bufev->timeout_read) == -1)
+			return (-1);
+	}
+	if (event & EV_WRITE) {
+		if (bufferevent_add(&bufev->ev_write, bufev->timeout_write) == -1)
+			return (-1);
+	}
+
+	bufev->enabled |= event;
+	return (0);
+}
+
+int
+bufferevent_disable(struct bufferevent *bufev, short event)
+{
+	if (event & EV_READ) {
+		if (event_del(&bufev->ev_read) == -1)
+			return (-1);
+	}
+	if (event & EV_WRITE) {
+		if (event_del(&bufev->ev_write) == -1)
+			return (-1);
+	}
+
+	bufev->enabled &= ~event;
+	return (0);
+}
+
+/*
+ * Sets the read and write timeout for a buffered event.
+ */
+
+void
+bufferevent_settimeout(struct bufferevent *bufev,
+    int timeout_read, int timeout_write) {
+	bufev->timeout_read = timeout_read;
+	bufev->timeout_write = timeout_write;
+
+	if (event_pending(&bufev->ev_read, EV_READ, NULL))
+		bufferevent_add(&bufev->ev_read, timeout_read);
+	if (event_pending(&bufev->ev_write, EV_WRITE, NULL))
+		bufferevent_add(&bufev->ev_write, timeout_write);
+}
+
+/*
+ * Sets the water marks
+ */
+
+void
+bufferevent_setwatermark(struct bufferevent *bufev, short events,
+    size_t lowmark, size_t highmark)
+{
+	if (events & EV_READ) {
+		bufev->wm_read.low = lowmark;
+		bufev->wm_read.high = highmark;
+	}
+
+	if (events & EV_WRITE) {
+		bufev->wm_write.low = lowmark;
+		bufev->wm_write.high = highmark;
+	}
+
+	/* If the watermarks changed then see if we should call read again */
+	bufferevent_read_pressure_cb(bufev->input,
+	    0, EVBUFFER_LENGTH(bufev->input), bufev);
+}
+
+int
+bufferevent_base_set(struct event_base *base, struct bufferevent *bufev)
+{
+	int res;
+
+	bufev->ev_base = base;
+
+	res = event_base_set(base, &bufev->ev_read);
+	if (res == -1)
+		return (res);
+
+	res = event_base_set(base, &bufev->ev_write);
+	return (res);
+}
diff --git a/libevent/event-config.h b/libevent/event-config.h
new file mode 100644
index 0000000..0a278b3
--- /dev/null
+++ b/libevent/event-config.h
@@ -0,0 +1,262 @@
+/* event-config.h
+ * Generated by autoconf; post-processed by libevent.
+ * Do not edit this file.
+ * Do not rely on macros in this file existing in later versions.
+ */
+#ifndef _EVENT_CONFIG_H_
+#define _EVENT_CONFIG_H_
+/* config.h.  Generated from config.h.in by configure.  */
+/* config.h.in.  Generated from configure.in by autoheader.  */
+
+/* Define if clock_gettime is available in libc */
+/* #undef _EVENT_DNS_USE_CPU_CLOCK_FOR_ID */
+
+/* Define is no secure id variant is available */
+#define _EVENT_DNS_USE_GETTIMEOFDAY_FOR_ID 1
+
+/* Define to 1 if you have the `clock_gettime' function. */
+/* #undef _EVENT_HAVE_CLOCK_GETTIME */
+
+/* Define if /dev/poll is available */
+/* #undef _EVENT_HAVE_DEVPOLL */
+
+/* Define to 1 if you have the <dlfcn.h> header file. */
+#define _EVENT_HAVE_DLFCN_H 1
+
+/* Define if your system supports the epoll system calls */
+/* #undef _EVENT_HAVE_EPOLL */
+
+/* Define to 1 if you have the `epoll_ctl' function. */
+/* #undef _EVENT_HAVE_EPOLL_CTL */
+
+/* Define if your system supports event ports */
+/* #undef _EVENT_HAVE_EVENT_PORTS */
+
+/* Define to 1 if you have the `fcntl' function. */
+#define _EVENT_HAVE_FCNTL 1
+
+/* Define to 1 if you have the <fcntl.h> header file. */
+#define _EVENT_HAVE_FCNTL_H 1
+
+/* Define to 1 if you have the `getaddrinfo' function. */
+#define _EVENT_HAVE_GETADDRINFO 1
+
+/* Define to 1 if you have the `getnameinfo' function. */
+#define _EVENT_HAVE_GETNAMEINFO 1
+
+/* Define to 1 if you have the `gettimeofday' function. */
+#define _EVENT_HAVE_GETTIMEOFDAY 1
+
+/* Define to 1 if you have the `inet_ntop' function. */
+#define _EVENT_HAVE_INET_NTOP 1
+
+/* Define to 1 if you have the <inttypes.h> header file. */
+#define _EVENT_HAVE_INTTYPES_H 1
+
+/* Define to 1 if you have the `kqueue' function. */
+#define _EVENT_HAVE_KQUEUE 1
+
+/* Define to 1 if you have the `nsl' library (-lnsl). */
+/* #undef _EVENT_HAVE_LIBNSL */
+
+/* Define to 1 if you have the `resolv' library (-lresolv). */
+#define _EVENT_HAVE_LIBRESOLV 1
+
+/* Define to 1 if you have the `rt' library (-lrt). */
+/* #undef _EVENT_HAVE_LIBRT */
+
+/* Define to 1 if you have the `socket' library (-lsocket). */
+/* #undef _EVENT_HAVE_LIBSOCKET */
+
+/* Define to 1 if you have the <memory.h> header file. */
+#define _EVENT_HAVE_MEMORY_H 1
+
+/* Define to 1 if you have the <netinet/in6.h> header file. */
+/* #undef _EVENT_HAVE_NETINET_IN6_H */
+
+/* Define to 1 if you have the `poll' function. */
+#define _EVENT_HAVE_POLL 1
+
+/* Define to 1 if you have the <poll.h> header file. */
+#define _EVENT_HAVE_POLL_H 1
+
+/* Define to 1 if you have the `port_create' function. */
+/* #undef _EVENT_HAVE_PORT_CREATE */
+
+/* Define to 1 if you have the <port.h> header file. */
+/* #undef _EVENT_HAVE_PORT_H */
+
+/* Define to 1 if you have the `select' function. */
+#define _EVENT_HAVE_SELECT 1
+
+/* Define if F_SETFD is defined in <fcntl.h> */
+#define _EVENT_HAVE_SETFD 1
+
+/* Define to 1 if you have the `sigaction' function. */
+#define _EVENT_HAVE_SIGACTION 1
+
+/* Define to 1 if you have the `signal' function. */
+#define _EVENT_HAVE_SIGNAL 1
+
+/* Define to 1 if you have the <signal.h> header file. */
+#define _EVENT_HAVE_SIGNAL_H 1
+
+/* Define to 1 if you have the <stdarg.h> header file. */
+#define _EVENT_HAVE_STDARG_H 1
+
+/* Define to 1 if you have the <stdint.h> header file. */
+#define _EVENT_HAVE_STDINT_H 1
+
+/* Define to 1 if you have the <stdlib.h> header file. */
+#define _EVENT_HAVE_STDLIB_H 1
+
+/* Define to 1 if you have the <strings.h> header file. */
+#define _EVENT_HAVE_STRINGS_H 1
+
+/* Define to 1 if you have the <string.h> header file. */
+#define _EVENT_HAVE_STRING_H 1
+
+/* Define to 1 if you have the `strlcpy' function. */
+#define _EVENT_HAVE_STRLCPY 1
+
+/* Define to 1 if you have the `strsep' function. */
+#define _EVENT_HAVE_STRSEP 1
+
+/* Define to 1 if you have the `strtok_r' function. */
+#define _EVENT_HAVE_STRTOK_R 1
+
+/* Define to 1 if you have the `strtoll' function. */
+#define _EVENT_HAVE_STRTOLL 1
+
+/* Define to 1 if the system has the type `struct in6_addr'. */
+#define _EVENT_HAVE_STRUCT_IN6_ADDR 1
+
+/* Define to 1 if you have the <sys/devpoll.h> header file. */
+/* #undef _EVENT_HAVE_SYS_DEVPOLL_H */
+
+/* Define to 1 if you have the <sys/epoll.h> header file. */
+/* #undef _EVENT_HAVE_SYS_EPOLL_H */
+
+/* Define to 1 if you have the <sys/event.h> header file. */
+#define _EVENT_HAVE_SYS_EVENT_H 1
+
+/* Define to 1 if you have the <sys/ioctl.h> header file. */
+#define _EVENT_HAVE_SYS_IOCTL_H 1
+
+/* Define to 1 if you have the <sys/param.h> header file. */
+#define _EVENT_HAVE_SYS_PARAM_H 1
+
+/* Define to 1 if you have the <sys/queue.h> header file. */
+#define _EVENT_HAVE_SYS_QUEUE_H 1
+
+/* Define to 1 if you have the <sys/select.h> header file. */
+#define _EVENT_HAVE_SYS_SELECT_H 1
+
+/* Define to 1 if you have the <sys/socket.h> header file. */
+#define _EVENT_HAVE_SYS_SOCKET_H 1
+
+/* Define to 1 if you have the <sys/stat.h> header file. */
+#define _EVENT_HAVE_SYS_STAT_H 1
+
+/* Define to 1 if you have the <sys/time.h> header file. */
+#define _EVENT_HAVE_SYS_TIME_H 1
+
+/* Define to 1 if you have the <sys/types.h> header file. */
+#define _EVENT_HAVE_SYS_TYPES_H 1
+
+/* Define if TAILQ_FOREACH is defined in <sys/queue.h> */
+#define _EVENT_HAVE_TAILQFOREACH 1
+
+/* Define if timeradd is defined in <sys/time.h> */
+#define _EVENT_HAVE_TIMERADD 1
+
+/* Define if timerclear is defined in <sys/time.h> */
+#define _EVENT_HAVE_TIMERCLEAR 1
+
+/* Define if timercmp is defined in <sys/time.h> */
+#define _EVENT_HAVE_TIMERCMP 1
+
+/* Define if timerisset is defined in <sys/time.h> */
+#define _EVENT_HAVE_TIMERISSET 1
+
+/* Define to 1 if the system has the type `uint16_t'. */
+#define _EVENT_HAVE_UINT16_T 1
+
+/* Define to 1 if the system has the type `uint32_t'. */
+#define _EVENT_HAVE_UINT32_T 1
+
+/* Define to 1 if the system has the type `uint64_t'. */
+#define _EVENT_HAVE_UINT64_T 1
+
+/* Define to 1 if the system has the type `uint8_t'. */
+#define _EVENT_HAVE_UINT8_T 1
+
+/* Define to 1 if you have the <unistd.h> header file. */
+#define _EVENT_HAVE_UNISTD_H 1
+
+/* Define to 1 if you have the `vasprintf' function. */
+#define _EVENT_HAVE_VASPRINTF 1
+
+/* Define if kqueue works correctly with pipes */
+#define _EVENT_HAVE_WORKING_KQUEUE 1
+
+/* Name of package */
+#define _EVENT_PACKAGE "libevent"
+
+/* Define to the address where bug reports for this package should be sent. */
+#define _EVENT_PACKAGE_BUGREPORT ""
+
+/* Define to the full name of this package. */
+#define _EVENT_PACKAGE_NAME ""
+
+/* Define to the full name and version of this package. */
+#define _EVENT_PACKAGE_STRING ""
+
+/* Define to the one symbol short name of this package. */
+#define _EVENT_PACKAGE_TARNAME ""
+
+/* Define to the version of this package. */
+#define _EVENT_PACKAGE_VERSION ""
+
+/* The size of `int', as computed by sizeof. */
+#define _EVENT_SIZEOF_INT 4
+
+/* The size of `long', as computed by sizeof. */
+#define _EVENT_SIZEOF_LONG 4
+
+/* The size of `long long', as computed by sizeof. */
+#define _EVENT_SIZEOF_LONG_LONG 8
+
+/* The size of `short', as computed by sizeof. */
+#define _EVENT_SIZEOF_SHORT 2
+
+/* Define to 1 if you have the ANSI C header files. */
+#define _EVENT_STDC_HEADERS 1
+
+/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
+#define _EVENT_TIME_WITH_SYS_TIME 1
+
+/* Version number of package */
+#define _EVENT_VERSION "1.4.8-stable"
+
+/* Define to appropriate substitue if compiler doesnt have __func__ */
+/* #undef _EVENT___func__ */
+
+/* Define to empty if `const' does not conform to ANSI C. */
+/* #undef _EVENT_const */
+
+/* Define to `__inline__' or `__inline' if that's what the C compiler
+   calls it, or to nothing if 'inline' is not supported under any name.  */
+#ifndef _EVENT___cplusplus
+/* #undef _EVENT_inline */
+#endif
+
+/* Define to `int' if <sys/types.h> does not define. */
+/* #undef _EVENT_pid_t */
+
+/* Define to `unsigned int' if <sys/types.h> does not define. */
+/* #undef _EVENT_size_t */
+
+/* Define to unsigned int if you dont have it */
+/* #undef _EVENT_socklen_t */
+#endif
diff --git a/libevent/event-fpm.h b/libevent/event-fpm.h
new file mode 100644
index 0000000..8625ca5
--- /dev/null
+++ b/libevent/event-fpm.h
@@ -0,0 +1,129 @@
+#define event_active _fpm_event_active
+#define event_add _fpm_event_add
+#define event_base_dispatch _fpm_event_base_dispatch
+#define event_base_free _fpm_event_base_free
+#define event_base_get_method _fpm_event_base_get_method
+#define event_base_loop _fpm_event_base_loop
+#define event_base_loopbreak _fpm_event_base_loopbreak
+#define event_base_loopexit _fpm_event_base_loopexit
+#define event_base_new _fpm_event_base_new
+#define event_base_once _fpm_event_base_once
+#define event_base_priority_init _fpm_event_base_priority_init
+#define event_base_set _fpm_event_base_set
+#define event_del _fpm_event_del
+#define event_dispatch _fpm_event_dispatch
+#define event_get_method _fpm_event_get_method
+#define event_get_version _fpm_event_get_version
+#define event_init _fpm_event_init
+#define event_loop _fpm_event_loop
+#define event_loopbreak _fpm_event_loopbreak
+#define event_loopexit _fpm_event_loopexit
+#define event_once _fpm_event_once
+#define event_pending _fpm_event_pending
+#define event_priority_init _fpm_event_priority_init
+#define event_priority_set _fpm_event_priority_set
+#define event_reinit _fpm_event_reinit
+#define event_set _fpm_event_set
+#define _event_debugx _fpm__event_debugx
+#define event_err _fpm_event_err
+#define event_errx _fpm_event_errx
+#define event_msgx _fpm_event_msgx
+#define event_set_log_callback _fpm_event_set_log_callback
+#define event_warn _fpm_event_warn
+#define event_warnx _fpm_event_warnx
+#define evutil_make_socket_nonblocking _fpm_evutil_make_socket_nonblocking
+#define evutil_snprintf _fpm_evutil_snprintf
+#define evutil_socketpair _fpm_evutil_socketpair
+#define evutil_strtoll _fpm_evutil_strtoll
+#define evutil_vsnprintf _fpm_evutil_vsnprintf
+#define evhttp_accept_socket _fpm_evhttp_accept_socket
+#define evhttp_add_header _fpm_evhttp_add_header
+#define evhttp_bind_socket _fpm_evhttp_bind_socket
+#define evhttp_clear_headers _fpm_evhttp_clear_headers
+#define evhttp_connection_connect _fpm_evhttp_connection_connect
+#define evhttp_connection_fail _fpm_evhttp_connection_fail
+#define evhttp_connection_free _fpm_evhttp_connection_free
+#define evhttp_connection_get_peer _fpm_evhttp_connection_get_peer
+#define evhttp_connection_new _fpm_evhttp_connection_new
+#define evhttp_connection_reset _fpm_evhttp_connection_reset
+#define evhttp_connection_set_base _fpm_evhttp_connection_set_base
+#define evhttp_connection_set_closecb _fpm_evhttp_connection_set_closecb
+#define evhttp_connection_set_local_address _fpm_evhttp_connection_set_local_address
+#define evhttp_connection_set_retries _fpm_evhttp_connection_set_retries
+#define evhttp_connection_set_timeout _fpm_evhttp_connection_set_timeout
+#define evhttp_decode_uri _fpm_evhttp_decode_uri
+#define evhttp_del_cb _fpm_evhttp_del_cb
+#define evhttp_encode_uri _fpm_evhttp_encode_uri
+#define evhttp_find_header _fpm_evhttp_find_header
+#define evhttp_free _fpm_evhttp_free
+#define evhttp_get_request _fpm_evhttp_get_request
+#define evhttp_hostportfile _fpm_evhttp_hostportfile
+#define evhttp_htmlescape _fpm_evhttp_htmlescape
+#define evhttp_make_header _fpm_evhttp_make_header
+#define evhttp_make_request _fpm_evhttp_make_request
+#define evhttp_new _fpm_evhttp_new
+#define evhttp_parse_firstline _fpm_evhttp_parse_firstline
+#define evhttp_parse_headers _fpm_evhttp_parse_headers
+#define evhttp_parse_query _fpm_evhttp_parse_query
+#define evhttp_read _fpm_evhttp_read
+#define evhttp_remove_header _fpm_evhttp_remove_header
+#define evhttp_request_free _fpm_evhttp_request_free
+#define evhttp_request_new _fpm_evhttp_request_new
+#define evhttp_request_set_chunked_cb _fpm_evhttp_request_set_chunked_cb
+#define evhttp_request_uri _fpm_evhttp_request_uri
+#define evhttp_response_code _fpm_evhttp_response_code
+#define evhttp_send_error _fpm_evhttp_send_error
+#define evhttp_send_page _fpm_evhttp_send_page
+#define evhttp_send_reply _fpm_evhttp_send_reply
+#define evhttp_send_reply_chunk _fpm_evhttp_send_reply_chunk
+#define evhttp_send_reply_end _fpm_evhttp_send_reply_end
+#define evhttp_send_reply_start _fpm_evhttp_send_reply_start
+#define evhttp_set_cb _fpm_evhttp_set_cb
+#define evhttp_set_gencb _fpm_evhttp_set_gencb
+#define evhttp_set_timeout _fpm_evhttp_set_timeout
+#define evhttp_start _fpm_evhttp_start
+#define evhttp_start_read _fpm_evhttp_start_read
+#define evhttp_write _fpm_evhttp_write
+#define evhttp_write_buffer _fpm_evhttp_write_buffer
+#define evbuffer_add _fpm_evbuffer_add
+#define evbuffer_add_buffer _fpm_evbuffer_add_buffer
+#define evbuffer_add_printf _fpm_evbuffer_add_printf
+#define evbuffer_add_vprintf _fpm_evbuffer_add_vprintf
+#define evbuffer_drain _fpm_evbuffer_drain
+#define evbuffer_expand _fpm_evbuffer_expand
+#define evbuffer_find _fpm_evbuffer_find
+#define evbuffer_free _fpm_evbuffer_free
+#define evbuffer_new _fpm_evbuffer_new
+#define evbuffer_read _fpm_evbuffer_read
+#define evbuffer_readline _fpm_evbuffer_readline
+#define evbuffer_remove _fpm_evbuffer_remove
+#define evbuffer_setcb _fpm_evbuffer_setcb
+#define evbuffer_write _fpm_evbuffer_write
+#define bufferevent_base_set _fpm_bufferevent_base_set
+#define bufferevent_disable _fpm_bufferevent_disable
+#define bufferevent_enable _fpm_bufferevent_enable
+#define bufferevent_free _fpm_bufferevent_free
+#define bufferevent_new _fpm_bufferevent_new
+#define bufferevent_priority_set _fpm_bufferevent_priority_set
+#define bufferevent_read _fpm_bufferevent_read
+#define bufferevent_read_pressure_cb _fpm_bufferevent_read_pressure_cb
+#define bufferevent_setcb _fpm_bufferevent_setcb
+#define bufferevent_setfd _fpm_bufferevent_setfd
+#define bufferevent_settimeout _fpm_bufferevent_settimeout
+#define bufferevent_setwatermark _fpm_bufferevent_setwatermark
+#define bufferevent_write _fpm_bufferevent_write
+#define bufferevent_write_buffer _fpm_bufferevent_write_buffer
+#define _event_strlcpy _fpm__event_strlcpy
+#define selectops _fpm_selectops
+#define pollops _fpm_pollops
+#define epollops _fpm_epollops
+#define devpollops _fpm_devpollops
+#define evportops _fpm_evportops
+#define kqops _fpm_kqops
+#define evsignal_add _fpm_evsignal_add
+#define evsignal_dealloc _fpm_evsignal_dealloc
+#define evsignal_del _fpm_evsignal_del
+#define evsignal_init _fpm_evsignal_init
+#define evsignal_process _fpm_evsignal_process
+#define _evsignal_restore_handler _fpm__evsignal_restore_handler
+#define _evsignal_set_handler _fpm__evsignal_set_handler
diff --git a/libevent/event-internal.h b/libevent/event-internal.h
new file mode 100644
index 0000000..7485f21
--- /dev/null
+++ b/libevent/event-internal.h
@@ -0,0 +1,98 @@
+/*
+ * Copyright (c) 2000-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _EVENT_INTERNAL_H_
+#define _EVENT_INTERNAL_H_
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#include "config.h"
+#include "min_heap.h"
+#include "evsignal.h"
+
+struct eventop {
+	const char *name;
+	void *(*init)(struct event_base *);
+	int (*add)(void *, struct event *);
+	int (*del)(void *, struct event *);
+	int (*dispatch)(struct event_base *, void *, struct timeval *);
+	void (*dealloc)(struct event_base *, void *);
+	/* set if we need to reinitialize the event base */
+	int need_reinit;
+};
+
+struct event_base {
+	const struct eventop *evsel;
+	void *evbase;
+	int event_count;		/* counts number of total events */
+	int event_count_active;	/* counts number of active events */
+
+	int event_gotterm;		/* Set to terminate loop */
+	int event_break;		/* Set to terminate loop immediately */
+
+	/* active event management */
+	struct event_list **activequeues;
+	int nactivequeues;
+
+	/* signal handling info */
+	struct evsignal_info sig;
+
+	struct event_list eventqueue;
+	struct timeval event_tv;
+
+	struct min_heap timeheap;
+
+	struct timeval tv_cache;
+};
+
+/* Internal use only: Functions that might be missing from <sys/queue.h> */
+#ifndef HAVE_TAILQFOREACH
+#define	TAILQ_FIRST(head)		((head)->tqh_first)
+#define	TAILQ_END(head)			NULL
+#define	TAILQ_NEXT(elm, field)		((elm)->field.tqe_next)
+#define TAILQ_FOREACH(var, head, field)					\
+	for((var) = TAILQ_FIRST(head);					\
+	    (var) != TAILQ_END(head);					\
+	    (var) = TAILQ_NEXT(var, field))
+#define	TAILQ_INSERT_BEFORE(listelm, elm, field) do {			\
+	(elm)->field.tqe_prev = (listelm)->field.tqe_prev;		\
+	(elm)->field.tqe_next = (listelm);				\
+	*(listelm)->field.tqe_prev = (elm);				\
+	(listelm)->field.tqe_prev = &(elm)->field.tqe_next;		\
+} while (0)
+#endif /* TAILQ_FOREACH */
+
+int _evsignal_set_handler(struct event_base *base, int evsignal,
+			  void (*fn)(int));
+int _evsignal_restore_handler(struct event_base *base, int evsignal);
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif /* _EVENT_INTERNAL_H_ */
diff --git a/libevent/event.3 b/libevent/event.3
new file mode 100644
index 0000000..5b33ec6
--- /dev/null
+++ b/libevent/event.3
@@ -0,0 +1,624 @@
+.\"	$OpenBSD: event.3,v 1.4 2002/07/12 18:50:48 provos Exp $
+.\"
+.\" Copyright (c) 2000 Artur Grabowski <art@openbsd.org>
+.\" All rights reserved.
+.\"
+.\" Redistribution and use in source and binary forms, with or without
+.\" modification, are permitted provided that the following conditions
+.\" are met:
+.\"
+.\" 1. Redistributions of source code must retain the above copyright
+.\"    notice, this list of conditions and the following disclaimer.
+.\" 2. Redistributions in binary form must reproduce the above copyright
+.\"    notice, this list of conditions and the following disclaimer in the
+.\"    documentation and/or other materials provided with the distribution.
+.\" 3. The name of the author may not be used to endorse or promote products
+.\"    derived from this software without specific prior written permission.
+.\"
+.\" THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
+.\" INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
+.\" AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
+.\" THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
+.\" EXEMPLARY, OR CONSEQUENTIAL  DAMAGES (INCLUDING, BUT NOT LIMITED TO,
+.\" PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
+.\" OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
+.\" WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
+.\" OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
+.\" ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+.\"
+.Dd August 8, 2000
+.Dt EVENT 3
+.Os
+.Sh NAME
+.Nm event_init ,
+.Nm event_dispatch ,
+.Nm event_loop ,
+.Nm event_loopexit ,
+.Nm event_loopbreak ,
+.Nm event_set ,
+.Nm event_base_dispatch ,
+.Nm event_base_loop ,
+.Nm event_base_loopexit ,
+.Nm event_base_loopbreak ,
+.Nm event_base_set ,
+.Nm event_base_free ,
+.Nm event_add ,
+.Nm event_del ,
+.Nm event_once ,
+.Nm event_base_once ,
+.Nm event_pending ,
+.Nm event_initialized ,
+.Nm event_priority_init ,
+.Nm event_priority_set ,
+.Nm evtimer_set ,
+.Nm evtimer_add ,
+.Nm evtimer_del ,
+.Nm evtimer_pending ,
+.Nm evtimer_initialized ,
+.Nm signal_set ,
+.Nm signal_add ,
+.Nm signal_del ,
+.Nm signal_pending ,
+.Nm signal_initialized ,
+.Nm bufferevent_new ,
+.Nm bufferevent_free ,
+.Nm bufferevent_write ,
+.Nm bufferevent_write_buffer ,
+.Nm bufferevent_read ,
+.Nm bufferevent_enable ,
+.Nm bufferevent_disable ,
+.Nm bufferevent_settimeout ,
+.Nm bufferevent_base_set ,
+.Nm evbuffer_new ,
+.Nm evbuffer_free ,
+.Nm evbuffer_add ,
+.Nm evbuffer_add_buffer ,
+.Nm evbuffer_add_printf ,
+.Nm evbuffer_add_vprintf ,
+.Nm evbuffer_drain ,
+.Nm evbuffer_write ,
+.Nm evbuffer_read ,
+.Nm evbuffer_find ,
+.Nm evbuffer_readline ,
+.Nm evhttp_new ,
+.Nm evhttp_bind_socket ,
+.Nm evhttp_free
+.Nd execute a function when a specific event occurs
+.Sh SYNOPSIS
+.Fd #include <sys/time.h>
+.Fd #include <event.h>
+.Ft "struct event_base *"
+.Fn "event_init" "void"
+.Ft int
+.Fn "event_dispatch" "void"
+.Ft int
+.Fn "event_loop" "int flags"
+.Ft int
+.Fn "event_loopexit" "struct timeval *tv"
+.Ft int
+.Fn "event_loopbreak" "void"
+.Ft void
+.Fn "event_set" "struct event *ev" "int fd" "short event" "void (*fn)(int, short, void *)" "void *arg"
+.Ft int
+.Fn "event_base_dispatch" "struct event_base *base"
+.Ft int
+.Fn "event_base_loop" "struct event_base *base" "int flags"
+.Ft int
+.Fn "event_base_loopexit" "struct event_base *base" "struct timeval *tv"
+.Ft int
+.Fn "event_base_loopbreak" "struct event_base *base"
+.Ft int
+.Fn "event_base_set" "struct event_base *base" "struct event *"
+.Ft void
+.Fn "event_base_free" "struct event_base *base"
+.Ft int
+.Fn "event_add" "struct event *ev" "struct timeval *tv"
+.Ft int
+.Fn "event_del" "struct event *ev"
+.Ft int
+.Fn "event_once" "int fd" "short event" "void (*fn)(int, short, void *)" "void *arg" "struct timeval *tv"
+.Ft int
+.Fn "event_base_once" "struct event_base *base" "int fd" "short event" "void (*fn)(int, short, void *)" "void *arg" "struct timeval *tv"
+.Ft int
+.Fn "event_pending" "struct event *ev" "short event" "struct timeval *tv"
+.Ft int
+.Fn "event_initialized" "struct event *ev"
+.Ft int
+.Fn "event_priority_init" "int npriorities"
+.Ft int
+.Fn "event_priority_set" "struct event *ev" "int priority"
+.Ft void
+.Fn "evtimer_set" "struct event *ev" "void (*fn)(int, short, void *)" "void *arg"
+.Ft void
+.Fn "evtimer_add" "struct event *ev" "struct timeval *"
+.Ft void
+.Fn "evtimer_del" "struct event *ev"
+.Ft int
+.Fn "evtimer_pending" "struct event *ev" "struct timeval *tv"
+.Ft int
+.Fn "evtimer_initialized" "struct event *ev"
+.Ft void
+.Fn "signal_set" "struct event *ev" "int signal" "void (*fn)(int, short, void *)" "void *arg"
+.Ft void
+.Fn "signal_add" "struct event *ev" "struct timeval *"
+.Ft void
+.Fn "signal_del" "struct event *ev"
+.Ft int
+.Fn "signal_pending" "struct event *ev" "struct timeval *tv"
+.Ft int
+.Fn "signal_initialized" "struct event *ev"
+.Ft "struct bufferevent *"
+.Fn "bufferevent_new" "int fd" "evbuffercb readcb" "evbuffercb writecb" "everrorcb" "void *cbarg"
+.Ft void
+.Fn "bufferevent_free" "struct bufferevent *bufev"
+.Ft int
+.Fn "bufferevent_write" "struct bufferevent *bufev" "void *data" "size_t size"
+.Ft int
+.Fn "bufferevent_write_buffer" "struct bufferevent *bufev" "struct evbuffer *buf"
+.Ft size_t
+.Fn "bufferevent_read" "struct bufferevent *bufev" "void *data" "size_t size"
+.Ft int
+.Fn "bufferevent_enable" "struct bufferevent *bufev" "short event"
+.Ft int
+.Fn "bufferevent_disable" "struct bufferevent *bufev" "short event"
+.Ft void
+.Fn "bufferevent_settimeout" "struct bufferevent *bufev" "int timeout_read" "int timeout_write"
+.Ft int
+.Fn "bufferevent_base_set" "struct event_base *base" "struct bufferevent *bufev"
+.Ft "struct evbuffer *"
+.Fn "evbuffer_new" "void"
+.Ft void
+.Fn "evbuffer_free" "struct evbuffer *buf"
+.Ft int
+.Fn "evbuffer_add" "struct evbuffer *buf" "const void *data" "size_t size"
+.Ft int
+.Fn "evbuffer_add_buffer" "struct evbuffer *dst" "struct evbuffer *src"
+.Ft int
+.Fn "evbuffer_add_printf" "struct evbuffer *buf" "const char *fmt" "..."
+.Ft int
+.Fn "evbuffer_add_vprintf" "struct evbuffer *buf" "const char *fmt" "va_list ap"
+.Ft void
+.Fn "evbuffer_drain" "struct evbuffer *buf" "size_t size"
+.Ft int
+.Fn "evbuffer_write" "struct evbuffer *buf" "int fd"
+.Ft int
+.Fn "evbuffer_read" "struct evbuffer *buf" "int fd" "int size"
+.Ft "u_char *"
+.Fn "evbuffer_find" "struct evbuffer *buf" "const u_char *data" "size_t size"
+.Ft "char *"
+.Fn "evbuffer_readline" "struct evbuffer *buf"
+.Ft "struct evhttp *"
+.Fn "evhttp_new" "struct event_base *base"
+.Ft int
+.Fn "evhttp_bind_socket" "struct evhttp *http" "const char *address" "u_short port"
+.Ft "void"
+.Fn "evhttp_free" "struct evhttp *http"
+.Ft int
+.Fa (*event_sigcb)(void) ;
+.Ft volatile sig_atomic_t
+.Fa event_gotsig ;
+.Sh DESCRIPTION
+The
+.Nm event
+API provides a mechanism to execute a function when a specific event
+on a file descriptor occurs or after a given time has passed.
+.Pp
+The
+.Nm event
+API needs to be initialized with
+.Fn event_init
+before it can be used.
+.Pp
+In order to process events, an application needs to call
+.Fn event_dispatch .
+This function only returns on error, and should replace the event core
+of the application program.
+.Pp
+The function
+.Fn event_set
+prepares the event structure
+.Fa ev
+to be used in future calls to
+.Fn event_add
+and
+.Fn event_del .
+The event will be prepared to call the function specified by the
+.Fa fn
+argument with an
+.Fa int
+argument indicating the file descriptor, a
+.Fa short
+argument indicating the type of event, and a
+.Fa void *
+argument given in the
+.Fa arg
+argument.
+The
+.Fa fd
+indicates the file descriptor that should be monitored for events.
+The events can be either
+.Va EV_READ ,
+.Va EV_WRITE ,
+or both,
+indicating that an application can read or write from the file descriptor
+respectively without blocking.
+.Pp
+The function
+.Fa fn
+will be called with the file descriptor that triggered the event and
+the type of event which will be either
+.Va EV_TIMEOUT ,
+.Va EV_SIGNAL ,
+.Va EV_READ ,
+or
+.Va EV_WRITE .
+Additionally, an event which has registered interest in more than one of the
+preceeding events, via bitwise-OR to
+.Fn event_set ,
+can provide its callback function with a bitwise-OR of more than one triggered
+event.
+The additional flag
+.Va EV_PERSIST
+makes an
+.Fn event_add
+persistent until
+.Fn event_del
+has been called.
+.Pp
+Once initialized, the
+.Fa ev
+structure can be used repeatedly with
+.Fn event_add
+and
+.Fn event_del
+and does not need to be reinitialized unless the function called and/or
+the argument to it are to be changed.
+However, when an
+.Fa ev
+structure has been added to libevent using
+.Fn event_add
+the structure must persist until the event occurs (assuming
+.Fa EV_PERSIST
+is not set) or is removed
+using
+.Fn event_del .
+You may not reuse the same
+.Fa ev
+structure for multiple monitored descriptors; each descriptor
+needs its own
+.Fa ev .
+.Pp
+The function
+.Fn event_add
+schedules the execution of the
+.Fa ev
+event when the event specified in
+.Fn event_set
+occurs or in at least the time specified in the
+.Fa tv .
+If
+.Fa tv
+is
+.Dv NULL ,
+no timeout occurs and the function will only be called
+if a matching event occurs on the file descriptor.
+The event in the
+.Fa ev
+argument must be already initialized by
+.Fn event_set
+and may not be used in calls to
+.Fn event_set
+until it has timed out or been removed with
+.Fn event_del .
+If the event in the
+.Fa ev
+argument already has a scheduled timeout, the old timeout will be
+replaced by the new one.
+.Pp
+The function
+.Fn event_del
+will cancel the event in the argument
+.Fa ev .
+If the event has already executed or has never been added
+the call will have no effect.
+.Pp
+The functions
+.Fn evtimer_set ,
+.Fn evtimer_add ,
+.Fn evtimer_del ,
+.Fn evtimer_initialized ,
+and
+.Fn evtimer_pending
+are abbreviations for common situations where only a timeout is required.
+The file descriptor passed will be \-1, and the event type will be
+.Va EV_TIMEOUT .
+.Pp
+The functions
+.Fn signal_set ,
+.Fn signal_add ,
+.Fn signal_del ,
+.Fn signal_initialized ,
+and
+.Fn signal_pending
+are abbreviations.
+The event type will be a persistent
+.Va EV_SIGNAL .
+That means
+.Fn signal_set
+adds
+.Va EV_PERSIST .
+.Pp
+In order to avoid races in signal handlers, the
+.Nm event
+API provides two variables:
+.Va event_sigcb
+and
+.Va event_gotsig .
+A signal handler
+sets
+.Va event_gotsig
+to indicate that a signal has been received.
+The application sets
+.Va event_sigcb
+to a callback function.
+After the signal handler sets
+.Va event_gotsig ,
+.Nm event_dispatch
+will execute the callback function to process received signals.
+The callback returns 1 when no events are registered any more.
+It can return \-1 to indicate an error to the
+.Nm event
+library, causing
+.Fn event_dispatch
+to terminate with
+.Va errno
+set to
+.Er EINTR .
+.Pp
+The function
+.Fn event_once
+is similar to
+.Fn event_set .
+However, it schedules a callback to be called exactly once and does not
+require the caller to prepare an
+.Fa event
+structure.
+This function supports
+.Fa EV_TIMEOUT ,
+.Fa EV_READ ,
+and
+.Fa EV_WRITE .
+.Pp
+The
+.Fn event_pending
+function can be used to check if the event specified by
+.Fa event
+is pending to run.
+If
+.Va EV_TIMEOUT
+was specified and
+.Fa tv
+is not
+.Dv NULL ,
+the expiration time of the event will be returned in
+.Fa tv .
+.Pp
+The
+.Fn event_initialized
+macro can be used to check if an event has been initialized.
+.Pp
+The
+.Nm event_loop
+function provides an interface for single pass execution of pending
+events.
+The flags
+.Va EVLOOP_ONCE
+and
+.Va EVLOOP_NONBLOCK
+are recognized.
+The
+.Nm event_loopexit
+function exits from the event loop. The next
+.Fn event_loop
+iteration after the
+given timer expires will complete normally (handling all queued events) then
+exit without blocking for events again. Subsequent invocations of
+.Fn event_loop
+will proceed normally.
+The
+.Nm event_loopbreak
+function exits from the event loop immediately.
+.Fn event_loop
+will abort after the next event is completed;
+.Fn event_loopbreak
+is typically invoked from this event's callback. This behavior is analogous
+to the "break;" statement. Subsequent invocations of
+.Fn event_loop
+will proceed normally.
+.Pp
+It is the responsibility of the caller to provide these functions with
+pre-allocated event structures.
+.Pp
+.Sh EVENT PRIORITIES
+By default
+.Nm libevent
+schedules all active events with the same priority.
+However, sometimes it is desirable to process some events with a higher
+priority than others.
+For that reason,
+.Nm libevent
+supports strict priority queues.
+Active events with a lower priority are always processed before events
+with a higher priority.
+.Pp
+The number of different priorities can be set initially with the
+.Fn event_priority_init
+function.
+This function should be called before the first call to
+.Fn event_dispatch .
+The
+.Fn event_priority_set
+function can be used to assign a priority to an event.
+By default,
+.Nm libevent
+assigns the middle priority to all events unless their priority
+is explicitly set.
+.Sh THREAD SAFE EVENTS
+.Nm Libevent
+has experimental support for thread-safe events.
+When initializing the library via
+.Fn event_init ,
+an event base is returned.
+This event base can be used in conjunction with calls to
+.Fn event_base_set ,
+.Fn event_base_dispatch ,
+.Fn event_base_loop ,
+.Fn event_base_loopexit ,
+.Fn bufferevent_base_set
+and
+.Fn event_base_free .
+.Fn event_base_set
+should be called after preparing an event with
+.Fn event_set ,
+as
+.Fn event_set
+assigns the provided event to the most recently created event base.
+.Fn bufferevent_base_set
+should be called after preparing a bufferevent with
+.Fn bufferevent_new .
+.Fn event_base_free
+should be used to free memory associated with the event base
+when it is no longer needed.
+.Sh BUFFERED EVENTS
+.Nm libevent
+provides an abstraction on top of the regular event callbacks.
+This abstraction is called a
+.Va "buffered event" .
+A buffered event provides input and output buffers that get filled
+and drained automatically.
+The user of a buffered event no longer deals directly with the IO,
+but instead is reading from input and writing to output buffers.
+.Pp
+A new bufferevent is created by
+.Fn bufferevent_new .
+The parameter
+.Fa fd
+specifies the file descriptor from which data is read and written to.
+This file descriptor is not allowed to be a
+.Xr pipe 2 .
+The next three parameters are callbacks.
+The read and write callback have the following form:
+.Ft void
+.Fn "(*cb)" "struct bufferevent *bufev" "void *arg" .
+The error callback has the following form:
+.Ft void
+.Fn "(*cb)" "struct bufferevent *bufev" "short what" "void *arg" .
+The argument is specified by the fourth parameter
+.Fa "cbarg" .
+A
+.Fa bufferevent struct
+pointer is returned on success, NULL on error.
+Both the read and the write callback may be NULL.
+The error callback has to be always provided.
+.Pp
+Once initialized, the bufferevent structure can be used repeatedly with
+bufferevent_enable() and bufferevent_disable().
+The flags parameter can be a combination of
+.Va EV_READ
+and
+.Va EV_WRITE .
+When read enabled the bufferevent will try to read from the file
+descriptor and call the read callback.
+The write callback is executed
+whenever the output buffer is drained below the write low watermark,
+which is
+.Va 0
+by default.
+.Pp
+The
+.Fn bufferevent_write
+function can be used to write data to the file descriptor.
+The data is appended to the output buffer and written to the descriptor
+automatically as it becomes available for writing.
+.Fn bufferevent_write
+returns 0 on success or \-1 on failure.
+The
+.Fn bufferevent_read
+function is used to read data from the input buffer,
+returning the amount of data read.
+.Pp
+If multiple bases are in use, bufferevent_base_set() must be called before
+enabling the bufferevent for the first time.
+.Sh NON-BLOCKING HTTP SUPPORT
+.Nm libevent
+provides a very thin HTTP layer that can be used both to host an HTTP
+server and also to make HTTP requests.
+An HTTP server can be created by calling
+.Fn evhttp_new .
+It can be bound to any port and address with the
+.Fn evhttp_bind_socket
+function.
+When the HTTP server is no longer used, it can be freed via
+.Fn evhttp_free .
+.Pp
+To be notified of HTTP requests, a user needs to register callbacks with the
+HTTP server.
+This can be done by calling
+.Fn evhttp_set_cb .
+The second argument is the URI for which a callback is being registered.
+The corresponding callback will receive an
+.Va struct evhttp_request
+object that contains all information about the request.
+.Pp
+This section does not document all the possible function calls; please
+check
+.Va event.h
+for the public interfaces.
+.Sh ADDITIONAL NOTES
+It is possible to disable support for
+.Va epoll , kqueue , devpoll , poll
+or
+.Va select
+by setting the environment variable
+.Va EVENT_NOEPOLL , EVENT_NOKQUEUE , EVENT_NODEVPOLL , EVENT_NOPOLL
+or
+.Va EVENT_NOSELECT ,
+respectively.
+By setting the environment variable
+.Va EVENT_SHOW_METHOD ,
+.Nm libevent
+displays the kernel notification method that it uses.
+.Sh RETURN VALUES
+Upon successful completion
+.Fn event_add
+and
+.Fn event_del
+return 0.
+Otherwise, \-1 is returned and the global variable errno is
+set to indicate the error.
+.Sh SEE ALSO
+.Xr kqueue 2 ,
+.Xr poll 2 ,
+.Xr select 2 ,
+.Xr evdns 3 ,
+.Xr timeout 9
+.Sh HISTORY
+The
+.Nm event
+API manpage is based on the
+.Xr timeout 9
+manpage by Artur Grabowski.
+The port of
+.Nm libevent
+to Windows is due to Michael A. Davis.
+Support for real-time signals is due to Taral.
+.Sh AUTHORS
+The
+.Nm event
+library was written by Niels Provos.
+.Sh BUGS
+This documentation is neither complete nor authoritative.
+If you are in doubt about the usage of this API then
+check the source code to find out how it works, write
+up the missing piece of documentation and send it to
+me for inclusion in this man page.
diff --git a/libevent/event.c b/libevent/event.c
new file mode 100644
index 0000000..826b7db
--- /dev/null
+++ b/libevent/event.c
@@ -0,0 +1,977 @@
+/*
+ * Copyright (c) 2000-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef WIN32
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+#endif
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else 
+#include <sys/_time.h>
+#endif
+#include <sys/queue.h>
+#include <stdio.h>
+#include <stdlib.h>
+#ifndef WIN32
+#include <unistd.h>
+#endif
+#include <errno.h>
+#include <signal.h>
+#include <string.h>
+#include <assert.h>
+#include <time.h>
+
+#include "event.h"
+#include "event-internal.h"
+#include "evutil.h"
+#include "log.h"
+
+#ifdef HAVE_EVENT_PORTS
+extern const struct eventop evportops;
+#endif
+#ifdef HAVE_SELECT
+extern const struct eventop selectops;
+#endif
+#ifdef HAVE_POLL
+extern const struct eventop pollops;
+#endif
+#ifdef HAVE_EPOLL
+extern const struct eventop epollops;
+#endif
+#ifdef HAVE_WORKING_KQUEUE
+extern const struct eventop kqops;
+#endif
+#ifdef HAVE_DEVPOLL
+extern const struct eventop devpollops;
+#endif
+#ifdef WIN32
+extern const struct eventop win32ops;
+#endif
+
+/* In order of preference */
+static const struct eventop *eventops[] = {
+#ifdef HAVE_EVENT_PORTS
+	&evportops,
+#endif
+#ifdef HAVE_WORKING_KQUEUE
+	&kqops,
+#endif
+#ifdef HAVE_EPOLL
+	&epollops,
+#endif
+#ifdef HAVE_DEVPOLL
+	&devpollops,
+#endif
+#ifdef HAVE_POLL
+	&pollops,
+#endif
+#ifdef HAVE_SELECT
+	&selectops,
+#endif
+#ifdef WIN32
+	&win32ops,
+#endif
+	NULL
+};
+
+/* Global state */
+struct event_base *current_base = NULL;
+extern struct event_base *evsignal_base;
+static int use_monotonic;
+
+/* Handle signals - This is a deprecated interface */
+int (*event_sigcb)(void);		/* Signal callback when gotsig is set */
+volatile sig_atomic_t event_gotsig;	/* Set in signal handler */
+
+/* Prototypes */
+static void	event_queue_insert(struct event_base *, struct event *, int);
+static void	event_queue_remove(struct event_base *, struct event *, int);
+static int	event_haveevents(struct event_base *);
+
+static void	event_process_active(struct event_base *);
+
+static int	timeout_next(struct event_base *, struct timeval **);
+static void	timeout_process(struct event_base *);
+static void	timeout_correct(struct event_base *, struct timeval *);
+
+static void
+detect_monotonic(void)
+{
+#if defined(HAVE_CLOCK_GETTIME) && defined(CLOCK_MONOTONIC)
+	struct timespec	ts;
+
+	if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0)
+		use_monotonic = 1;
+#endif
+}
+
+static int
+gettime(struct event_base *base, struct timeval *tp)
+{
+	if (base->tv_cache.tv_sec) {
+		*tp = base->tv_cache;
+		return (0);
+	}
+
+#if defined(HAVE_CLOCK_GETTIME) && defined(CLOCK_MONOTONIC)
+	if (use_monotonic) {
+		struct timespec	ts;
+
+		if (clock_gettime(CLOCK_MONOTONIC, &ts) == -1)
+			return (-1);
+
+		tp->tv_sec = ts.tv_sec;
+		tp->tv_usec = ts.tv_nsec / 1000;
+		return (0);
+	}
+#endif
+
+	return (evutil_gettimeofday(tp, NULL));
+}
+
+struct event_base *
+event_init(void)
+{
+	struct event_base *base = event_base_new();
+
+	if (base != NULL)
+		current_base = base;
+
+	return (base);
+}
+
+struct event_base *
+event_base_new(void)
+{
+	int i;
+	struct event_base *base;
+
+	if ((base = calloc(1, sizeof(struct event_base))) == NULL)
+		event_err(1, "%s: calloc", __func__);
+
+	event_sigcb = NULL;
+	event_gotsig = 0;
+
+	detect_monotonic();
+	gettime(base, &base->event_tv);
+	
+	min_heap_ctor(&base->timeheap);
+	TAILQ_INIT(&base->eventqueue);
+	base->sig.ev_signal_pair[0] = -1;
+	base->sig.ev_signal_pair[1] = -1;
+	
+	base->evbase = NULL;
+	for (i = 0; eventops[i] && !base->evbase; i++) {
+		base->evsel = eventops[i];
+
+		base->evbase = base->evsel->init(base);
+	}
+
+	if (base->evbase == NULL)
+		event_errx(1, "%s: no event mechanism available", __func__);
+
+	if (getenv("EVENT_SHOW_METHOD")) 
+		event_msgx("libevent using: %s\n",
+			   base->evsel->name);
+
+	/* allocate a single active event queue */
+	event_base_priority_init(base, 1);
+
+	return (base);
+}
+
+void
+event_base_free(struct event_base *base)
+{
+	int i;
+
+	if (base == NULL && current_base)
+		base = current_base;
+	if (base == current_base)
+		current_base = NULL;
+
+	assert(base);
+
+	if (base->evsel->dealloc != NULL)
+		base->evsel->dealloc(base, base->evbase);
+
+	min_heap_dtor(&base->timeheap);
+
+	for (i = 0; i < base->nactivequeues; ++i)
+		free(base->activequeues[i]);
+	free(base->activequeues);
+
+	free(base);
+}
+
+/* reinitialized the event base after a fork */
+int
+event_reinit(struct event_base *base)
+{
+	const struct eventop *evsel = base->evsel;
+	void *evbase = base->evbase;
+	int res = 0;
+	struct event *ev;
+
+	/* check if this event mechanism requires reinit */
+	if (!evsel->need_reinit)
+		return (0);
+
+	/* prevent internal delete */
+	if (base->sig.ev_signal_added) {
+		event_queue_remove(base, &base->sig.ev_signal,
+		    EVLIST_INSERTED);
+		base->sig.ev_signal_added = 0;
+	}
+	
+	if (base->evsel->dealloc != NULL)
+		base->evsel->dealloc(base, base->evbase);
+	evbase = base->evbase = evsel->init(base);
+	if (base->evbase == NULL)
+		event_errx(1, "%s: could not reinitialize event mechanism",
+		    __func__);
+
+	TAILQ_FOREACH(ev, &base->eventqueue, ev_next) {
+		if (evsel->add(evbase, ev) == -1)
+			res = -1;
+	}
+
+	return (res);
+}
+
+int
+event_priority_init(int npriorities)
+{
+  return event_base_priority_init(current_base, npriorities);
+}
+
+int
+event_base_priority_init(struct event_base *base, int npriorities)
+{
+	int i;
+
+	if (base->event_count_active)
+		return (-1);
+
+	if (base->nactivequeues && npriorities != base->nactivequeues) {
+		for (i = 0; i < base->nactivequeues; ++i) {
+			free(base->activequeues[i]);
+		}
+		free(base->activequeues);
+	}
+
+	/* Allocate our priority queues */
+	base->nactivequeues = npriorities;
+	base->activequeues = (struct event_list **)calloc(base->nactivequeues,
+	    npriorities * sizeof(struct event_list *));
+	if (base->activequeues == NULL)
+		event_err(1, "%s: calloc", __func__);
+
+	for (i = 0; i < base->nactivequeues; ++i) {
+		base->activequeues[i] = malloc(sizeof(struct event_list));
+		if (base->activequeues[i] == NULL)
+			event_err(1, "%s: malloc", __func__);
+		TAILQ_INIT(base->activequeues[i]);
+	}
+
+	return (0);
+}
+
+int
+event_haveevents(struct event_base *base)
+{
+	return (base->event_count > 0);
+}
+
+/*
+ * Active events are stored in priority queues.  Lower priorities are always
+ * process before higher priorities.  Low priority events can starve high
+ * priority ones.
+ */
+
+static void
+event_process_active(struct event_base *base)
+{
+	struct event *ev;
+	struct event_list *activeq = NULL;
+	int i;
+	short ncalls;
+
+	for (i = 0; i < base->nactivequeues; ++i) {
+		if (TAILQ_FIRST(base->activequeues[i]) != NULL) {
+			activeq = base->activequeues[i];
+			break;
+		}
+	}
+
+	assert(activeq != NULL);
+
+	for (ev = TAILQ_FIRST(activeq); ev; ev = TAILQ_FIRST(activeq)) {
+		if (ev->ev_events & EV_PERSIST)
+			event_queue_remove(base, ev, EVLIST_ACTIVE);
+		else
+			event_del(ev);
+		
+		/* Allows deletes to work */
+		ncalls = ev->ev_ncalls;
+		ev->ev_pncalls = &ncalls;
+		while (ncalls) {
+			ncalls--;
+			ev->ev_ncalls = ncalls;
+			(*ev->ev_callback)((int)ev->ev_fd, ev->ev_res, ev->ev_arg);
+			if (event_gotsig || base->event_break)
+				return;
+		}
+	}
+}
+
+/*
+ * Wait continously for events.  We exit only if no events are left.
+ */
+
+int
+event_dispatch(void)
+{
+	return (event_loop(0));
+}
+
+int
+event_base_dispatch(struct event_base *event_base)
+{
+  return (event_base_loop(event_base, 0));
+}
+
+const char *
+event_base_get_method(struct event_base *base)
+{
+	assert(base);
+	return (base->evsel->name);
+}
+
+static void
+event_loopexit_cb(int fd, short what, void *arg)
+{
+	struct event_base *base = arg;
+	base->event_gotterm = 1;
+}
+
+/* not thread safe */
+int
+event_loopexit(const struct timeval *tv)
+{
+	return (event_once(-1, EV_TIMEOUT, event_loopexit_cb,
+		    current_base, tv));
+
+}
+
+int
+event_base_loopexit(struct event_base *event_base, const struct timeval *tv)
+{
+	return (event_base_once(event_base, -1, EV_TIMEOUT, event_loopexit_cb,
+		    event_base, tv));
+}
+
+/* not thread safe */
+int
+event_loopbreak(void)
+{
+	return (event_base_loopbreak(current_base));
+}
+
+int
+event_base_loopbreak(struct event_base *event_base)
+{
+	if (event_base == NULL)
+		return (-1);
+
+	event_base->event_break = 1;
+	return (0);
+}
+
+
+
+/* not thread safe */
+
+int
+event_loop(int flags)
+{
+	return event_base_loop(current_base, flags);
+}
+
+int
+event_base_loop(struct event_base *base, int flags)
+{
+	const struct eventop *evsel = base->evsel;
+	void *evbase = base->evbase;
+	struct timeval tv;
+	struct timeval *tv_p;
+	int res, done;
+
+	if (&base->sig.ev_signal_added)
+		evsignal_base = base;
+	done = 0;
+	while (!done) {
+		/* Terminate the loop if we have been asked to */
+		if (base->event_gotterm) {
+			base->event_gotterm = 0;
+			break;
+		}
+
+		if (base->event_break) {
+			base->event_break = 0;
+			break;
+		}
+
+		/* You cannot use this interface for multi-threaded apps */
+		while (event_gotsig) {
+			event_gotsig = 0;
+			if (event_sigcb) {
+				res = (*event_sigcb)();
+				if (res == -1) {
+					errno = EINTR;
+					return (-1);
+				}
+			}
+		}
+
+		timeout_correct(base, &tv);
+
+		tv_p = &tv;
+		if (!base->event_count_active && !(flags & EVLOOP_NONBLOCK)) {
+			timeout_next(base, &tv_p);
+		} else {
+			/* 
+			 * if we have active events, we just poll new events
+			 * without waiting.
+			 */
+			evutil_timerclear(&tv);
+		}
+		
+		/* If we have no events, we just exit */
+		if (!event_haveevents(base)) {
+			event_debug(("%s: no events registered.", __func__));
+			return (1);
+		}
+
+		/* update last old time */
+		gettime(base, &base->event_tv);
+
+		/* clear time cache */
+		base->tv_cache.tv_sec = 0;
+
+		res = evsel->dispatch(base, evbase, tv_p);
+
+		if (res == -1)
+			return (-1);
+		gettime(base, &base->tv_cache);
+
+		timeout_process(base);
+
+		if (base->event_count_active) {
+			event_process_active(base);
+			if (!base->event_count_active && (flags & EVLOOP_ONCE))
+				done = 1;
+		} else if (flags & EVLOOP_NONBLOCK)
+			done = 1;
+	}
+
+	event_debug(("%s: asked to terminate loop.", __func__));
+	return (0);
+}
+
+/* Sets up an event for processing once */
+
+struct event_once {
+	struct event ev;
+
+	void (*cb)(int, short, void *);
+	void *arg;
+};
+
+/* One-time callback, it deletes itself */
+
+static void
+event_once_cb(int fd, short events, void *arg)
+{
+	struct event_once *eonce = arg;
+
+	(*eonce->cb)(fd, events, eonce->arg);
+	free(eonce);
+}
+
+/* not threadsafe, event scheduled once. */
+int
+event_once(int fd, short events,
+    void (*callback)(int, short, void *), void *arg, const struct timeval *tv)
+{
+	return event_base_once(current_base, fd, events, callback, arg, tv);
+}
+
+/* Schedules an event once */
+int
+event_base_once(struct event_base *base, int fd, short events,
+    void (*callback)(int, short, void *), void *arg, const struct timeval *tv)
+{
+	struct event_once *eonce;
+	struct timeval etv;
+	int res;
+
+	/* We cannot support signals that just fire once */
+	if (events & EV_SIGNAL)
+		return (-1);
+
+	if ((eonce = calloc(1, sizeof(struct event_once))) == NULL)
+		return (-1);
+
+	eonce->cb = callback;
+	eonce->arg = arg;
+
+	if (events == EV_TIMEOUT) {
+		if (tv == NULL) {
+			evutil_timerclear(&etv);
+			tv = &etv;
+		}
+
+		evtimer_set(&eonce->ev, event_once_cb, eonce);
+	} else if (events & (EV_READ|EV_WRITE)) {
+		events &= EV_READ|EV_WRITE;
+
+		event_set(&eonce->ev, fd, events, event_once_cb, eonce);
+	} else {
+		/* Bad event combination */
+		free(eonce);
+		return (-1);
+	}
+
+	res = event_base_set(base, &eonce->ev);
+	if (res == 0)
+		res = event_add(&eonce->ev, tv);
+	if (res != 0) {
+		free(eonce);
+		return (res);
+	}
+
+	return (0);
+}
+
+void
+event_set(struct event *ev, int fd, short events,
+	  void (*callback)(int, short, void *), void *arg)
+{
+	/* Take the current base - caller needs to set the real base later */
+	ev->ev_base = current_base;
+
+	ev->ev_callback = callback;
+	ev->ev_arg = arg;
+	ev->ev_fd = fd;
+	ev->ev_events = events;
+	ev->ev_res = 0;
+	ev->ev_flags = EVLIST_INIT;
+	ev->ev_ncalls = 0;
+	ev->ev_pncalls = NULL;
+
+	min_heap_elem_init(ev);
+
+	/* by default, we put new events into the middle priority */
+	if(current_base)
+		ev->ev_pri = current_base->nactivequeues/2;
+}
+
+int
+event_base_set(struct event_base *base, struct event *ev)
+{
+	/* Only innocent events may be assigned to a different base */
+	if (ev->ev_flags != EVLIST_INIT)
+		return (-1);
+
+	ev->ev_base = base;
+	ev->ev_pri = base->nactivequeues/2;
+
+	return (0);
+}
+
+/*
+ * Set's the priority of an event - if an event is already scheduled
+ * changing the priority is going to fail.
+ */
+
+int
+event_priority_set(struct event *ev, int pri)
+{
+	if (ev->ev_flags & EVLIST_ACTIVE)
+		return (-1);
+	if (pri < 0 || pri >= ev->ev_base->nactivequeues)
+		return (-1);
+
+	ev->ev_pri = pri;
+
+	return (0);
+}
+
+/*
+ * Checks if a specific event is pending or scheduled.
+ */
+
+int
+event_pending(struct event *ev, short event, struct timeval *tv)
+{
+	struct timeval	now, res;
+	int flags = 0;
+
+	if (ev->ev_flags & EVLIST_INSERTED)
+		flags |= (ev->ev_events & (EV_READ|EV_WRITE|EV_SIGNAL));
+	if (ev->ev_flags & EVLIST_ACTIVE)
+		flags |= ev->ev_res;
+	if (ev->ev_flags & EVLIST_TIMEOUT)
+		flags |= EV_TIMEOUT;
+
+	event &= (EV_TIMEOUT|EV_READ|EV_WRITE|EV_SIGNAL);
+
+	/* See if there is a timeout that we should report */
+	if (tv != NULL && (flags & event & EV_TIMEOUT)) {
+		gettime(ev->ev_base, &now);
+		evutil_timersub(&ev->ev_timeout, &now, &res);
+		/* correctly remap to real time */
+		evutil_gettimeofday(&now, NULL);
+		evutil_timeradd(&now, &res, tv);
+	}
+
+	return (flags & event);
+}
+
+int
+event_add(struct event *ev, const struct timeval *tv)
+{
+	struct event_base *base = ev->ev_base;
+	const struct eventop *evsel = base->evsel;
+	void *evbase = base->evbase;
+	int res = 0;
+
+	event_debug((
+		 "event_add: event: %p, %s%s%scall %p",
+		 ev,
+		 ev->ev_events & EV_READ ? "EV_READ " : " ",
+		 ev->ev_events & EV_WRITE ? "EV_WRITE " : " ",
+		 tv ? "EV_TIMEOUT " : " ",
+		 ev->ev_callback));
+
+	assert(!(ev->ev_flags & ~EVLIST_ALL));
+
+	/*
+	 * prepare for timeout insertion further below, if we get a
+	 * failure on any step, we should not change any state.
+	 */
+	if (tv != NULL && !(ev->ev_flags & EVLIST_TIMEOUT)) {
+		if (min_heap_reserve(&base->timeheap,
+			1 + min_heap_size(&base->timeheap)) == -1)
+			return (-1);  /* ENOMEM == errno */
+	}
+
+	if ((ev->ev_events & (EV_READ|EV_WRITE|EV_SIGNAL)) &&
+	    !(ev->ev_flags & (EVLIST_INSERTED|EVLIST_ACTIVE))) {
+		res = evsel->add(evbase, ev);
+		if (res != -1)
+			event_queue_insert(base, ev, EVLIST_INSERTED);
+	}
+
+	/* 
+	 * we should change the timout state only if the previous event
+	 * addition succeeded.
+	 */
+	if (res != -1 && tv != NULL) {
+		struct timeval now;
+
+		/* 
+		 * we already reserved memory above for the case where we
+		 * are not replacing an exisiting timeout.
+		 */
+		if (ev->ev_flags & EVLIST_TIMEOUT)
+			event_queue_remove(base, ev, EVLIST_TIMEOUT);
+
+		/* Check if it is active due to a timeout.  Rescheduling
+		 * this timeout before the callback can be executed
+		 * removes it from the active list. */
+		if ((ev->ev_flags & EVLIST_ACTIVE) &&
+		    (ev->ev_res & EV_TIMEOUT)) {
+			/* See if we are just active executing this
+			 * event in a loop
+			 */
+			if (ev->ev_ncalls && ev->ev_pncalls) {
+				/* Abort loop */
+				*ev->ev_pncalls = 0;
+			}
+			
+			event_queue_remove(base, ev, EVLIST_ACTIVE);
+		}
+
+		gettime(base, &now);
+		evutil_timeradd(&now, tv, &ev->ev_timeout);
+
+		event_debug((
+			 "event_add: timeout in %ld seconds, call %p",
+			 tv->tv_sec, ev->ev_callback));
+
+		event_queue_insert(base, ev, EVLIST_TIMEOUT);
+	}
+
+	return (0);
+}
+
+int
+event_del(struct event *ev)
+{
+	struct event_base *base;
+	const struct eventop *evsel;
+	void *evbase;
+
+	event_debug(("event_del: %p, callback %p",
+		 ev, ev->ev_callback));
+
+	/* An event without a base has not been added */
+	if (ev->ev_base == NULL)
+		return (-1);
+
+	base = ev->ev_base;
+	evsel = base->evsel;
+	evbase = base->evbase;
+
+	assert(!(ev->ev_flags & ~EVLIST_ALL));
+
+	/* See if we are just active executing this event in a loop */
+	if (ev->ev_ncalls && ev->ev_pncalls) {
+		/* Abort loop */
+		*ev->ev_pncalls = 0;
+	}
+
+	if (ev->ev_flags & EVLIST_TIMEOUT)
+		event_queue_remove(base, ev, EVLIST_TIMEOUT);
+
+	if (ev->ev_flags & EVLIST_ACTIVE)
+		event_queue_remove(base, ev, EVLIST_ACTIVE);
+
+	if (ev->ev_flags & EVLIST_INSERTED) {
+		event_queue_remove(base, ev, EVLIST_INSERTED);
+		return (evsel->del(evbase, ev));
+	}
+
+	return (0);
+}
+
+void
+event_active(struct event *ev, int res, short ncalls)
+{
+	/* We get different kinds of events, add them together */
+	if (ev->ev_flags & EVLIST_ACTIVE) {
+		ev->ev_res |= res;
+		return;
+	}
+
+	ev->ev_res = res;
+	ev->ev_ncalls = ncalls;
+	ev->ev_pncalls = NULL;
+	event_queue_insert(ev->ev_base, ev, EVLIST_ACTIVE);
+}
+
+static int
+timeout_next(struct event_base *base, struct timeval **tv_p)
+{
+	struct timeval now;
+	struct event *ev;
+	struct timeval *tv = *tv_p;
+
+	if ((ev = min_heap_top(&base->timeheap)) == NULL) {
+		/* if no time-based events are active wait for I/O */
+		*tv_p = NULL;
+		return (0);
+	}
+
+	if (gettime(base, &now) == -1)
+		return (-1);
+
+	if (evutil_timercmp(&ev->ev_timeout, &now, <=)) {
+		evutil_timerclear(tv);
+		return (0);
+	}
+
+	evutil_timersub(&ev->ev_timeout, &now, tv);
+
+	assert(tv->tv_sec >= 0);
+	assert(tv->tv_usec >= 0);
+
+	event_debug(("timeout_next: in %ld seconds", tv->tv_sec));
+	return (0);
+}
+
+/*
+ * Determines if the time is running backwards by comparing the current
+ * time against the last time we checked.  Not needed when using clock
+ * monotonic.
+ */
+
+static void
+timeout_correct(struct event_base *base, struct timeval *tv)
+{
+	struct event **pev;
+	unsigned int size;
+	struct timeval off;
+
+	if (use_monotonic)
+		return;
+
+	/* Check if time is running backwards */
+	gettime(base, tv);
+	if (evutil_timercmp(tv, &base->event_tv, >=)) {
+		base->event_tv = *tv;
+		return;
+	}
+
+	event_debug(("%s: time is running backwards, corrected",
+		    __func__));
+	evutil_timersub(&base->event_tv, tv, &off);
+
+	/*
+	 * We can modify the key element of the node without destroying
+	 * the key, beause we apply it to all in the right order.
+	 */
+	pev = base->timeheap.p;
+	size = base->timeheap.n;
+	for (; size-- > 0; ++pev) {
+		struct timeval *ev_tv = &(**pev).ev_timeout;
+		evutil_timersub(ev_tv, &off, ev_tv);
+	}
+}
+
+void
+timeout_process(struct event_base *base)
+{
+	struct timeval now;
+	struct event *ev;
+
+	if (min_heap_empty(&base->timeheap))
+		return;
+
+	gettime(base, &now);
+
+	while ((ev = min_heap_top(&base->timeheap))) {
+		if (evutil_timercmp(&ev->ev_timeout, &now, >))
+			break;
+
+		/* delete this event from the I/O queues */
+		event_del(ev);
+
+		event_debug(("timeout_process: call %p",
+			 ev->ev_callback));
+		event_active(ev, EV_TIMEOUT, 1);
+	}
+}
+
+void
+event_queue_remove(struct event_base *base, struct event *ev, int queue)
+{
+	if (!(ev->ev_flags & queue))
+		event_errx(1, "%s: %p(fd %d) not on queue %x", __func__,
+			   ev, ev->ev_fd, queue);
+
+	if (~ev->ev_flags & EVLIST_INTERNAL)
+		base->event_count--;
+
+	ev->ev_flags &= ~queue;
+	switch (queue) {
+	case EVLIST_INSERTED:
+		TAILQ_REMOVE(&base->eventqueue, ev, ev_next);
+		break;
+	case EVLIST_ACTIVE:
+		base->event_count_active--;
+		TAILQ_REMOVE(base->activequeues[ev->ev_pri],
+		    ev, ev_active_next);
+		break;
+	case EVLIST_TIMEOUT:
+		min_heap_erase(&base->timeheap, ev);
+		break;
+	default:
+		event_errx(1, "%s: unknown queue %x", __func__, queue);
+	}
+}
+
+void
+event_queue_insert(struct event_base *base, struct event *ev, int queue)
+{
+	if (ev->ev_flags & queue) {
+		/* Double insertion is possible for active events */
+		if (queue & EVLIST_ACTIVE)
+			return;
+
+		event_errx(1, "%s: %p(fd %d) already on queue %x", __func__,
+			   ev, ev->ev_fd, queue);
+	}
+
+	if (~ev->ev_flags & EVLIST_INTERNAL)
+		base->event_count++;
+
+	ev->ev_flags |= queue;
+	switch (queue) {
+	case EVLIST_INSERTED:
+		TAILQ_INSERT_TAIL(&base->eventqueue, ev, ev_next);
+		break;
+	case EVLIST_ACTIVE:
+		base->event_count_active++;
+		TAILQ_INSERT_TAIL(base->activequeues[ev->ev_pri],
+		    ev,ev_active_next);
+		break;
+	case EVLIST_TIMEOUT: {
+		min_heap_push(&base->timeheap, ev);
+		break;
+	}
+	default:
+		event_errx(1, "%s: unknown queue %x", __func__, queue);
+	}
+}
+
+/* Functions for debugging */
+
+const char *
+event_get_version(void)
+{
+	return (VERSION);
+}
+
+/* 
+ * No thread-safe interface needed - the information should be the same
+ * for all threads.
+ */
+
+const char *
+event_get_method(void)
+{
+	return (current_base->evsel->name);
+}
diff --git a/libevent/event.h b/libevent/event.h
new file mode 100644
index 0000000..d67ecb5
--- /dev/null
+++ b/libevent/event.h
@@ -0,0 +1,1203 @@
+/*
+ * Copyright (c) 2000-2007 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _EVENT_H_
+#define _EVENT_H_
+
+#include "event-fpm.h"
+
+/** @mainpage
+
+  @section intro Introduction
+
+  libevent is an event notification library for developing scalable network
+  servers.  The libevent API provides a mechanism to execute a callback
+  function when a specific event occurs on a file descriptor or after a
+  timeout has been reached. Furthermore, libevent also support callbacks due
+  to signals or regular timeouts.
+
+  libevent is meant to replace the event loop found in event driven network
+  servers. An application just needs to call event_dispatch() and then add or
+  remove events dynamically without having to change the event loop.
+
+  Currently, libevent supports /dev/poll, kqueue(2), select(2), poll(2) and
+  epoll(4). It also has experimental support for real-time signals. The
+  internal event mechanism is completely independent of the exposed event API,
+  and a simple update of libevent can provide new functionality without having
+  to redesign the applications. As a result, Libevent allows for portable
+  application development and provides the most scalable event notification
+  mechanism available on an operating system. Libevent can also be used for
+  multi-threaded aplications; see Steven Grimm's explanation. Libevent should
+  compile on Linux, *BSD, Mac OS X, Solaris and Windows.
+
+  @section usage Standard usage
+
+  Every program that uses libevent must include the <event.h> header, and pass
+  the -levent flag to the linker.  Before using any of the functions in the
+  library, you must call event_init() or event_base_new() to perform one-time
+  initialization of the libevent library.
+
+  @section event Event notification
+
+  For each file descriptor that you wish to monitor, you must declare an event
+  structure and call event_set() to initialize the members of the structure.
+  To enable notification, you add the structure to the list of monitored
+  events by calling event_add().  The event structure must remain allocated as
+  long as it is active, so it should be allocated on the heap. Finally, you
+  call event_dispatch() to loop and dispatch events.
+
+  @section bufferevent I/O Buffers
+
+  libevent provides an abstraction on top of the regular event callbacks. This
+  abstraction is called a buffered event. A buffered event provides input and
+  output buffers that get filled and drained automatically. The user of a
+  buffered event no longer deals directly with the I/O, but instead is reading
+  from input and writing to output buffers.
+
+  Once initialized via bufferevent_new(), the bufferevent structure can be
+  used repeatedly with bufferevent_enable() and bufferevent_disable().
+  Instead of reading and writing directly to a socket, you would call
+  bufferevent_read() and bufferevent_write().
+
+  When read enabled the bufferevent will try to read from the file descriptor
+  and call the read callback. The write callback is executed whenever the
+  output buffer is drained below the write low watermark, which is 0 by
+  default.
+
+  @section timers Timers
+
+  libevent can also be used to create timers that invoke a callback after a
+  certain amount of time has expired. The evtimer_set() function prepares an
+  event struct to be used as a timer. To activate the timer, call
+  evtimer_add(). Timers can be deactivated by calling evtimer_del().
+
+  @section timeouts Timeouts
+
+  In addition to simple timers, libevent can assign timeout events to file
+  descriptors that are triggered whenever a certain amount of time has passed
+  with no activity on a file descriptor.  The timeout_set() function
+  initializes an event struct for use as a timeout. Once initialized, the
+  event must be activated by using timeout_add().  To cancel the timeout, call
+  timeout_del().
+
+  @section evdns Asynchronous DNS resolution
+
+  libevent provides an asynchronous DNS resolver that should be used instead
+  of the standard DNS resolver functions.  These functions can be imported by
+  including the <evdns.h> header in your program. Before using any of the
+  resolver functions, you must call evdns_init() to initialize the library. To
+  convert a hostname to an IP address, you call the evdns_resolve_ipv4()
+  function.  To perform a reverse lookup, you would call the
+  evdns_resolve_reverse() function.  All of these functions use callbacks to
+  avoid blocking while the lookup is performed.
+
+  @section evhttp Event-driven HTTP servers
+
+  libevent provides a very simple event-driven HTTP server that can be
+  embedded in your program and used to service HTTP requests.
+
+  To use this capability, you need to include the <evhttp.h> header in your
+  program.  You create the server by calling evhttp_new(). Add addresses and
+  ports to listen on with evhttp_bind_socket(). You then register one or more
+  callbacks to handle incoming requests.  Each URI can be assigned a callback
+  via the evhttp_set_cb() function.  A generic callback function can also be
+  registered via evhttp_set_gencb(); this callback will be invoked if no other
+  callbacks have been registered for a given URI.
+
+  @section evrpc A framework for RPC servers and clients
+ 
+  libevents provides a framework for creating RPC servers and clients.  It
+  takes care of marshaling and unmarshaling all data structures.
+
+  @section api API Reference
+
+  To browse the complete documentation of the libevent API, click on any of
+  the following links.
+
+  event.h
+  The primary libevent header
+
+  evdns.h
+  Asynchronous DNS resolution
+
+  evhttp.h
+  An embedded libevent-based HTTP server
+
+  evrpc.h
+  A framework for creating RPC servers and clients
+
+ */
+
+/** @file event.h
+
+  A library for writing event-driven network servers
+
+ */
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#include <event-config.h>
+#ifdef _EVENT_HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+#ifdef _EVENT_HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+#ifdef _EVENT_HAVE_STDINT_H
+#include <stdint.h>
+#endif
+#include <stdarg.h>
+
+/* Solaris does not have it */
+#ifndef timersub
+
+#define timeradd(tvp, uvp, vvp)								\
+	do {													\
+		(vvp)->tv_sec = (tvp)->tv_sec + (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec + (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec >= 1000000) {					\
+			(vvp)->tv_sec++;								\
+			(vvp)->tv_usec -= 1000000;						\
+		}													\
+	} while (0)
+
+#define	timersub(tvp, uvp, vvp)								\
+	do {													\
+		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec < 0) {							\
+			(vvp)->tv_sec--;								\
+			(vvp)->tv_usec += 1000000;						\
+		}													\
+	} while (0)
+
+#endif
+
+/* For int types. */
+#include <evutil.h>
+
+#ifdef WIN32
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+typedef unsigned char u_char;
+typedef unsigned short u_short;
+#endif
+
+#define EVLIST_TIMEOUT	0x01
+#define EVLIST_INSERTED	0x02
+#define EVLIST_SIGNAL	0x04
+#define EVLIST_ACTIVE	0x08
+#define EVLIST_INTERNAL	0x10
+#define EVLIST_INIT	0x80
+
+/* EVLIST_X_ Private space: 0x1000-0xf000 */
+#define EVLIST_ALL	(0xf000 | 0x9f)
+
+#define EV_TIMEOUT	0x01
+#define EV_READ		0x02
+#define EV_WRITE	0x04
+#define EV_SIGNAL	0x08
+#define EV_PERSIST	0x10	/* Persistant event */
+
+/* Fix so that ppl dont have to run with <sys/queue.h> */
+#ifndef TAILQ_ENTRY
+#define _EVENT_DEFINED_TQENTRY
+#define TAILQ_ENTRY(type)						\
+struct {								\
+	struct type *tqe_next;	/* next element */			\
+	struct type **tqe_prev;	/* address of previous next element */	\
+}
+#endif /* !TAILQ_ENTRY */
+
+struct event_base;
+struct event {
+	TAILQ_ENTRY (event) ev_next;
+	TAILQ_ENTRY (event) ev_active_next;
+	TAILQ_ENTRY (event) ev_signal_next;
+	unsigned int min_heap_idx;	/* for managing timeouts */
+
+	struct event_base *ev_base;
+
+	int ev_fd;
+	short ev_events;
+	short ev_ncalls;
+	short *ev_pncalls;	/* Allows deletes in callback */
+
+	struct timeval ev_timeout;
+
+	int ev_pri;		/* smaller numbers are higher priority */
+
+	void (*ev_callback)(int, short, void *arg);
+	void *ev_arg;
+
+	int ev_res;		/* result passed to event callback */
+	int ev_flags;
+};
+
+#define EVENT_SIGNAL(ev)	(int)(ev)->ev_fd
+#define EVENT_FD(ev)		(int)(ev)->ev_fd
+
+/*
+ * Key-Value pairs.  Can be used for HTTP headers but also for
+ * query argument parsing.
+ */
+struct evkeyval {
+	TAILQ_ENTRY(evkeyval) next;
+
+	char *key;
+	char *value;
+};
+
+#ifdef _EVENT_DEFINED_TQENTRY
+#undef TAILQ_ENTRY
+struct event_list;
+struct evkeyvalq;
+#undef _EVENT_DEFINED_TQENTRY
+#else
+TAILQ_HEAD (event_list, event);
+TAILQ_HEAD (evkeyvalq, evkeyval);
+#endif /* _EVENT_DEFINED_TQENTRY */
+
+/**
+  Initialize the event API.
+
+  Use event_base_new() to initialize a new event base, but does not set
+  the current_base global.   If using only event_base_new(), each event
+  added must have an event base set with event_base_set()
+
+  @see event_base_set(), event_base_free(), event_init()
+ */
+struct event_base *event_base_new(void);
+
+/**
+  Initialize the event API.
+
+  The event API needs to be initialized with event_init() before it can be
+  used.  Sets the current_base global representing the default base for
+  events that have no base associated with them.
+
+  @see event_base_set(), event_base_new()
+ */
+struct event_base *event_init(void);
+
+/**
+  Reinitialized the event base after a fork
+
+  Some event mechanisms do not survive across fork.   The event base needs
+  to be reinitialized with the event_reinit() function.
+
+  @param base the event base that needs to be re-initialized
+  @return 0 if successful, or -1 if some events could not be re-added.
+  @see event_base_new(), event_init()
+*/
+int event_reinit(struct event_base *base);
+
+/**
+  Loop to process events.
+
+  In order to process events, an application needs to call
+  event_dispatch().  This function only returns on error, and should
+  replace the event core of the application program.
+
+  @see event_base_dispatch()
+ */
+int event_dispatch(void);
+
+
+/**
+  Threadsafe event dispatching loop.
+
+  @param eb the event_base structure returned by event_init()
+  @see event_init(), event_dispatch()
+ */
+int event_base_dispatch(struct event_base *);
+
+
+/**
+ Get the kernel event notification mechanism used by libevent.
+ 
+ @param eb the event_base structure returned by event_base_new()
+ @return a string identifying the kernel event mechanism (kqueue, epoll, etc.)
+ */
+const char *event_base_get_method(struct event_base *);
+        
+        
+/**
+  Deallocate all memory associated with an event_base, and free the base.
+
+  Note that this function will not close any fds or free any memory passed
+  to event_set as the argument to callback.
+
+  @param eb an event_base to be freed
+ */
+void event_base_free(struct event_base *);
+
+
+#define _EVENT_LOG_DEBUG 0
+#define _EVENT_LOG_MSG   1
+#define _EVENT_LOG_WARN  2
+#define _EVENT_LOG_ERR   3
+typedef void (*event_log_cb)(int severity, const char *msg);
+/**
+  Redirect libevent's log messages.
+
+  @param cb a function taking two arguments: an integer severity between
+     _EVENT_LOG_DEBUG and _EVENT_LOG_ERR, and a string.  If cb is NULL,
+	 then the default log is used.
+  */
+void event_set_log_callback(event_log_cb cb);
+
+/**
+  Associate a different event base with an event.
+
+  @param eb the event base
+  @param ev the event
+ */
+int event_base_set(struct event_base *, struct event *);
+
+/**
+ event_loop() flags
+ */
+/*@{*/
+#define EVLOOP_ONCE	0x01	/**< Block at most once. */
+#define EVLOOP_NONBLOCK	0x02	/**< Do not block. */
+/*@}*/
+
+/**
+  Handle events.
+
+  This is a more flexible version of event_dispatch().
+
+  @param flags any combination of EVLOOP_ONCE | EVLOOP_NONBLOCK
+  @return 0 if successful, -1 if an error occurred, or 1 if no events were
+    registered.
+  @see event_loopexit(), event_base_loop()
+*/
+int event_loop(int);
+
+/**
+  Handle events (threadsafe version).
+
+  This is a more flexible version of event_base_dispatch().
+
+  @param eb the event_base structure returned by event_init()
+  @param flags any combination of EVLOOP_ONCE | EVLOOP_NONBLOCK
+  @return 0 if successful, -1 if an error occurred, or 1 if no events were
+    registered.
+  @see event_loopexit(), event_base_loop()
+  */
+int event_base_loop(struct event_base *, int);
+
+/**
+  Exit the event loop after the specified time.
+
+  The next event_loop() iteration after the given timer expires will
+  complete normally (handling all queued events) then exit without
+  blocking for events again.
+
+  Subsequent invocations of event_loop() will proceed normally.
+
+  @param tv the amount of time after which the loop should terminate.
+  @return 0 if successful, or -1 if an error occurred
+  @see event_loop(), event_base_loop(), event_base_loopexit()
+  */
+int event_loopexit(const struct timeval *);
+
+
+/**
+  Exit the event loop after the specified time (threadsafe variant).
+
+  The next event_base_loop() iteration after the given timer expires will
+  complete normally (handling all queued events) then exit without
+  blocking for events again.
+
+  Subsequent invocations of event_base_loop() will proceed normally.
+
+  @param eb the event_base structure returned by event_init()
+  @param tv the amount of time after which the loop should terminate.
+  @return 0 if successful, or -1 if an error occurred
+  @see event_loopexit()
+ */
+int event_base_loopexit(struct event_base *, const struct timeval *);
+
+/**
+  Abort the active event_loop() immediately.
+
+  event_loop() will abort the loop after the next event is completed;
+  event_loopbreak() is typically invoked from this event's callback.
+  This behavior is analogous to the "break;" statement.
+
+  Subsequent invocations of event_loop() will proceed normally.
+
+  @return 0 if successful, or -1 if an error occurred
+  @see event_base_loopbreak(), event_loopexit()
+ */
+int event_loopbreak(void);
+
+/**
+  Abort the active event_base_loop() immediately.
+
+  event_base_loop() will abort the loop after the next event is completed;
+  event_base_loopbreak() is typically invoked from this event's callback.
+  This behavior is analogous to the "break;" statement.
+
+  Subsequent invocations of event_loop() will proceed normally.
+
+  @param eb the event_base structure returned by event_init()
+  @return 0 if successful, or -1 if an error occurred
+  @see event_base_loopexit
+ */
+int event_base_loopbreak(struct event_base *);
+
+
+/**
+  Add a timer event.
+
+  @param ev the event struct
+  @param tv timeval struct
+ */
+#define evtimer_add(ev, tv)		event_add(ev, tv)
+
+
+/**
+  Define a timer event.
+
+  @param ev event struct to be modified
+  @param cb callback function
+  @param arg argument that will be passed to the callback function
+ */
+#define evtimer_set(ev, cb, arg)	event_set(ev, -1, 0, cb, arg)
+
+
+/**
+ * Delete a timer event.
+ *
+ * @param ev the event struct to be disabled
+ */
+#define evtimer_del(ev)			event_del(ev)
+#define evtimer_pending(ev, tv)		event_pending(ev, EV_TIMEOUT, tv)
+#define evtimer_initialized(ev)		((ev)->ev_flags & EVLIST_INIT)
+
+/**
+ * Add a timeout event.
+ *
+ * @param ev the event struct to be disabled
+ * @param tv the timeout value, in seconds
+ */
+#define timeout_add(ev, tv)		event_add(ev, tv)
+
+
+/**
+ * Define a timeout event.
+ *
+ * @param ev the event struct to be defined
+ * @param cb the callback to be invoked when the timeout expires
+ * @param arg the argument to be passed to the callback
+ */
+#define timeout_set(ev, cb, arg)	event_set(ev, -1, 0, cb, arg)
+
+
+/**
+ * Disable a timeout event.
+ *
+ * @param ev the timeout event to be disabled
+ */
+#define timeout_del(ev)			event_del(ev)
+
+#define timeout_pending(ev, tv)		event_pending(ev, EV_TIMEOUT, tv)
+#define timeout_initialized(ev)		((ev)->ev_flags & EVLIST_INIT)
+
+#define signal_add(ev, tv)		event_add(ev, tv)
+#define signal_set(ev, x, cb, arg)	\
+	event_set(ev, x, EV_SIGNAL|EV_PERSIST, cb, arg)
+#define signal_del(ev)			event_del(ev)
+#define signal_pending(ev, tv)		event_pending(ev, EV_SIGNAL, tv)
+#define signal_initialized(ev)		((ev)->ev_flags & EVLIST_INIT)
+
+/**
+  Prepare an event structure to be added.
+
+  The function event_set() prepares the event structure ev to be used in
+  future calls to event_add() and event_del().  The event will be prepared to
+  call the function specified by the fn argument with an int argument
+  indicating the file descriptor, a short argument indicating the type of
+  event, and a void * argument given in the arg argument.  The fd indicates
+  the file descriptor that should be monitored for events.  The events can be
+  either EV_READ, EV_WRITE, or both.  Indicating that an application can read
+  or write from the file descriptor respectively without blocking.
+
+  The function fn will be called with the file descriptor that triggered the
+  event and the type of event which will be either EV_TIMEOUT, EV_SIGNAL,
+  EV_READ, or EV_WRITE.  The additional flag EV_PERSIST makes an event_add()
+  persistent until event_del() has been called.
+
+  @param ev an event struct to be modified
+  @param fd the file descriptor to be monitored
+  @param event desired events to monitor; can be EV_READ and/or EV_WRITE
+  @param fn callback function to be invoked when the event occurs
+  @param arg an argument to be passed to the callback function
+
+  @see event_add(), event_del(), event_once()
+
+ */
+void event_set(struct event *, int, short, void (*)(int, short, void *), void *);
+
+/**
+  Schedule a one-time event to occur.
+
+  The function event_once() is similar to event_set().  However, it schedules
+  a callback to be called exactly once and does not require the caller to
+  prepare an event structure.
+
+  @param fd a file descriptor to monitor
+  @param events event(s) to monitor; can be any of EV_TIMEOUT | EV_READ |
+         EV_WRITE
+  @param callback callback function to be invoked when the event occurs
+  @param arg an argument to be passed to the callback function
+  @param timeout the maximum amount of time to wait for the event, or NULL
+         to wait forever
+  @return 0 if successful, or -1 if an error occurred
+  @see event_set()
+
+ */
+int event_once(int, short, void (*)(int, short, void *), void *,
+    const struct timeval *);
+
+
+/**
+  Schedule a one-time event (threadsafe variant)
+
+  The function event_base_once() is similar to event_set().  However, it
+  schedules a callback to be called exactly once and does not require the
+  caller to prepare an event structure.
+
+  @param base an event_base returned by event_init()
+  @param fd a file descriptor to monitor
+  @param events event(s) to monitor; can be any of EV_TIMEOUT | EV_READ |
+         EV_WRITE
+  @param callback callback function to be invoked when the event occurs
+  @param arg an argument to be passed to the callback function
+  @param timeout the maximum amount of time to wait for the event, or NULL
+         to wait forever
+  @return 0 if successful, or -1 if an error occurred
+  @see event_once()
+ */
+int event_base_once(struct event_base *base, int fd, short events,
+    void (*callback)(int, short, void *), void *arg,
+    const struct timeval *timeout);
+
+
+/**
+  Add an event to the set of monitored events.
+
+  The function event_add() schedules the execution of the ev event when the
+  event specified in event_set() occurs or in at least the time specified in
+  the tv.  If tv is NULL, no timeout occurs and the function will only be
+  called if a matching event occurs on the file descriptor.  The event in the
+  ev argument must be already initialized by event_set() and may not be used
+  in calls to event_set() until it has timed out or been removed with
+  event_del().  If the event in the ev argument already has a scheduled
+  timeout, the old timeout will be replaced by the new one.
+
+  @param ev an event struct initialized via event_set()
+  @param timeout the maximum amount of time to wait for the event, or NULL
+         to wait forever
+  @return 0 if successful, or -1 if an error occurred
+  @see event_del(), event_set()
+  */
+int event_add(struct event *ev, const struct timeval *timeout);
+
+
+/**
+  Remove an event from the set of monitored events.
+
+  The function event_del() will cancel the event in the argument ev.  If the
+  event has already executed or has never been added the call will have no
+  effect.
+
+  @param ev an event struct to be removed from the working set
+  @return 0 if successful, or -1 if an error occurred
+  @see event_add()
+ */
+int event_del(struct event *);
+
+void event_active(struct event *, int, short);
+
+
+/**
+  Checks if a specific event is pending or scheduled.
+
+  @param ev an event struct previously passed to event_add()
+  @param event the requested event type; any of EV_TIMEOUT|EV_READ|
+         EV_WRITE|EV_SIGNAL
+  @param tv an alternate timeout (FIXME - is this true?)
+
+  @return 1 if the event is pending, or 0 if the event has not occurred
+
+ */
+int event_pending(struct event *ev, short event, struct timeval *tv);
+
+
+/**
+  Test if an event structure has been initialized.
+
+  The event_initialized() macro can be used to check if an event has been
+  initialized.
+
+  @param ev an event structure to be tested
+  @return 1 if the structure has been initialized, or 0 if it has not been
+          initialized
+ */
+#ifdef WIN32
+#define event_initialized(ev)		((ev)->ev_flags & EVLIST_INIT && (ev)->ev_fd != (int)INVALID_HANDLE_VALUE)
+#else
+#define event_initialized(ev)		((ev)->ev_flags & EVLIST_INIT)
+#endif
+
+
+/**
+  Get the libevent version number.
+
+  @return a string containing the version number of libevent
+ */
+const char *event_get_version(void);
+
+
+/**
+  Get the kernel event notification mechanism used by libevent.
+
+  @return a string identifying the kernel event mechanism (kqueue, epoll, etc.)
+ */
+const char *event_get_method(void);
+
+
+/**
+  Set the number of different event priorities.
+
+  By default libevent schedules all active events with the same priority.
+  However, some time it is desirable to process some events with a higher
+  priority than others.  For that reason, libevent supports strict priority
+  queues.  Active events with a lower priority are always processed before
+  events with a higher priority.
+
+  The number of different priorities can be set initially with the
+  event_priority_init() function.  This function should be called before the
+  first call to event_dispatch().  The event_priority_set() function can be
+  used to assign a priority to an event.  By default, libevent assigns the
+  middle priority to all events unless their priority is explicitly set.
+
+  @param npriorities the maximum number of priorities
+  @return 0 if successful, or -1 if an error occurred
+  @see event_base_priority_init(), event_priority_set()
+
+ */
+int	event_priority_init(int);
+
+
+/**
+  Set the number of different event priorities (threadsafe variant).
+
+  See the description of event_priority_init() for more information.
+
+  @param eb the event_base structure returned by event_init()
+  @param npriorities the maximum number of priorities
+  @return 0 if successful, or -1 if an error occurred
+  @see event_priority_init(), event_priority_set()
+ */
+int	event_base_priority_init(struct event_base *, int);
+
+
+/**
+  Assign a priority to an event.
+
+  @param ev an event struct
+  @param priority the new priority to be assigned
+  @return 0 if successful, or -1 if an error occurred
+  @see event_priority_init()
+  */
+int	event_priority_set(struct event *, int);
+
+
+/* These functions deal with buffering input and output */
+
+struct evbuffer {
+	u_char *buffer;
+	u_char *orig_buffer;
+
+	size_t misalign;
+	size_t totallen;
+	size_t off;
+
+	void (*cb)(struct evbuffer *, size_t, size_t, void *);
+	void *cbarg;
+};
+
+/* Just for error reporting - use other constants otherwise */
+#define EVBUFFER_READ		0x01
+#define EVBUFFER_WRITE		0x02
+#define EVBUFFER_EOF		0x10
+#define EVBUFFER_ERROR		0x20
+#define EVBUFFER_TIMEOUT	0x40
+
+struct bufferevent;
+typedef void (*evbuffercb)(struct bufferevent *, void *);
+typedef void (*everrorcb)(struct bufferevent *, short what, void *);
+
+struct event_watermark {
+	size_t low;
+	size_t high;
+};
+
+struct bufferevent {
+	struct event_base *ev_base;
+
+	struct event ev_read;
+	struct event ev_write;
+
+	struct evbuffer *input;
+	struct evbuffer *output;
+
+	struct event_watermark wm_read;
+	struct event_watermark wm_write;
+
+	evbuffercb readcb;
+	evbuffercb writecb;
+	everrorcb errorcb;
+	void *cbarg;
+
+	int timeout_read;	/* in seconds */
+	int timeout_write;	/* in seconds */
+
+	short enabled;	/* events that are currently enabled */
+};
+
+
+/**
+  Create a new bufferevent.
+
+  libevent provides an abstraction on top of the regular event callbacks.
+  This abstraction is called a buffered event.  A buffered event provides
+  input and output buffers that get filled and drained automatically.  The
+  user of a buffered event no longer deals directly with the I/O, but
+  instead is reading from input and writing to output buffers.
+
+  Once initialized, the bufferevent structure can be used repeatedly with
+  bufferevent_enable() and bufferevent_disable().
+
+  When read enabled the bufferevent will try to read from the file descriptor
+  and call the read callback.  The write callback is executed whenever the
+  output buffer is drained below the write low watermark, which is 0 by
+  default.
+
+  If multiple bases are in use, bufferevent_base_set() must be called before
+  enabling the bufferevent for the first time.
+
+  @param fd the file descriptor from which data is read and written to.
+  		This file descriptor is not allowed to be a pipe(2).
+  @param readcb callback to invoke when there is data to be read, or NULL if
+         no callback is desired
+  @param writecb callback to invoke when the file descriptor is ready for
+         writing, or NULL if no callback is desired
+  @param errorcb callback to invoke when there is an error on the file
+         descriptor
+  @param cbarg an argument that will be supplied to each of the callbacks
+         (readcb, writecb, and errorcb)
+  @return a pointer to a newly allocated bufferevent struct, or NULL if an
+          error occurred
+  @see bufferevent_base_set(), bufferevent_free()
+  */
+struct bufferevent *bufferevent_new(int fd,
+    evbuffercb readcb, evbuffercb writecb, everrorcb errorcb, void *cbarg);
+
+
+/**
+  Assign a bufferevent to a specific event_base.
+
+  @param base an event_base returned by event_init()
+  @param bufev a bufferevent struct returned by bufferevent_new()
+  @return 0 if successful, or -1 if an error occurred
+  @see bufferevent_new()
+ */
+int bufferevent_base_set(struct event_base *base, struct bufferevent *bufev);
+
+
+/**
+  Assign a priority to a bufferevent.
+
+  @param bufev a bufferevent struct
+  @param pri the priority to be assigned
+  @return 0 if successful, or -1 if an error occurred
+  */
+int bufferevent_priority_set(struct bufferevent *bufev, int pri);
+
+
+/**
+  Deallocate the storage associated with a bufferevent structure.
+
+  @param bufev the bufferevent structure to be freed.
+  */
+void bufferevent_free(struct bufferevent *bufev);
+
+
+/**
+  Changes the callbacks for a bufferevent.
+
+  @param bufev the bufferevent object for which to change callbacks
+  @param readcb callback to invoke when there is data to be read, or NULL if
+         no callback is desired
+  @param writecb callback to invoke when the file descriptor is ready for
+         writing, or NULL if no callback is desired
+  @param errorcb callback to invoke when there is an error on the file
+         descriptor
+  @param cbarg an argument that will be supplied to each of the callbacks
+         (readcb, writecb, and errorcb)
+  @see bufferevent_new()
+  */
+void bufferevent_setcb(struct bufferevent *bufev,
+    evbuffercb readcb, evbuffercb writecb, everrorcb errorcb, void *cbarg);
+
+/**
+  Changes the file descriptor on which the bufferevent operates.
+
+  @param bufev the bufferevent object for which to change the file descriptor
+  @param fd the file descriptor to operate on
+*/
+void bufferevent_setfd(struct bufferevent *bufev, int fd);
+
+/**
+  Write data to a bufferevent buffer.
+
+  The bufferevent_write() function can be used to write data to the file
+  descriptor.  The data is appended to the output buffer and written to the
+  descriptor automatically as it becomes available for writing.
+
+  @param bufev the bufferevent to be written to
+  @param data a pointer to the data to be written
+  @param size the length of the data, in bytes
+  @return 0 if successful, or -1 if an error occurred
+  @see bufferevent_write_buffer()
+  */
+int bufferevent_write(struct bufferevent *bufev,
+    const void *data, size_t size);
+
+
+/**
+  Write data from an evbuffer to a bufferevent buffer.  The evbuffer is
+  being drained as a result.
+
+  @param bufev the bufferevent to be written to
+  @param buf the evbuffer to be written
+  @return 0 if successful, or -1 if an error occurred
+  @see bufferevent_write()
+ */
+int bufferevent_write_buffer(struct bufferevent *bufev, struct evbuffer *buf);
+
+
+/**
+  Read data from a bufferevent buffer.
+
+  The bufferevent_read() function is used to read data from the input buffer.
+
+  @param bufev the bufferevent to be read from
+  @param data pointer to a buffer that will store the data
+  @param size the size of the data buffer, in bytes
+  @return the amount of data read, in bytes.
+ */
+size_t bufferevent_read(struct bufferevent *bufev, void *data, size_t size);
+
+/**
+  Enable a bufferevent.
+
+  @param bufev the bufferevent to be enabled
+  @param event any combination of EV_READ | EV_WRITE.
+  @return 0 if successful, or -1 if an error occurred
+  @see bufferevent_disable()
+ */
+int bufferevent_enable(struct bufferevent *bufev, short event);
+
+
+/**
+  Disable a bufferevent.
+
+  @param bufev the bufferevent to be disabled
+  @param event any combination of EV_READ | EV_WRITE.
+  @return 0 if successful, or -1 if an error occurred
+  @see bufferevent_enable()
+ */
+int bufferevent_disable(struct bufferevent *bufev, short event);
+
+
+/**
+  Set the read and write timeout for a buffered event.
+
+  @param bufev the bufferevent to be modified
+  @param timeout_read the read timeout
+  @param timeout_write the write timeout
+ */
+void bufferevent_settimeout(struct bufferevent *bufev,
+    int timeout_read, int timeout_write);
+
+
+/**
+  Sets the watermarks for read and write events.
+
+  On input, a bufferevent does not invoke the user read callback unless
+  there is at least low watermark data in the buffer.   If the read buffer
+  is beyond the high watermark, the buffevent stops reading from the network.
+
+  On output, the user write callback is invoked whenever the buffered data
+  falls below the low watermark.
+
+  @param bufev the bufferevent to be modified
+  @param events EV_READ, EV_WRITE or both
+  @param lowmark the lower watermark to set
+  @param highmark the high watermark to set
+*/
+
+void bufferevent_setwatermark(struct bufferevent *bufev, short events,
+    size_t lowmark, size_t highmark);
+
+#define EVBUFFER_LENGTH(x)	(x)->off
+#define EVBUFFER_DATA(x)	(x)->buffer
+#define EVBUFFER_INPUT(x)	(x)->input
+#define EVBUFFER_OUTPUT(x)	(x)->output
+
+
+/**
+  Allocate storage for a new evbuffer.
+
+  @return a pointer to a newly allocated evbuffer struct, or NULL if an error
+          occurred
+ */
+struct evbuffer *evbuffer_new(void);
+
+
+/**
+  Deallocate storage for an evbuffer.
+
+  @param pointer to the evbuffer to be freed
+ */
+void evbuffer_free(struct evbuffer *);
+
+
+/**
+  Expands the available space in an event buffer.
+
+  Expands the available space in the event buffer to at least datlen
+
+  @param buf the event buffer to be expanded
+  @param datlen the new minimum length requirement
+  @return 0 if successful, or -1 if an error occurred
+*/
+int evbuffer_expand(struct evbuffer *, size_t);
+
+
+/**
+  Append data to the end of an evbuffer.
+
+  @param buf the event buffer to be appended to
+  @param data pointer to the beginning of the data buffer
+  @param datlen the number of bytes to be copied from the data buffer
+ */
+int evbuffer_add(struct evbuffer *, const void *, size_t);
+
+
+
+/**
+  Read data from an event buffer and drain the bytes read.
+
+  @param buf the event buffer to be read from
+  @param data the destination buffer to store the result
+  @param datlen the maximum size of the destination buffer
+  @return the number of bytes read
+ */
+int evbuffer_remove(struct evbuffer *, void *, size_t);
+
+
+/**
+ * Read a single line from an event buffer.
+ *
+ * Reads a line terminated by either '\r\n', '\n\r' or '\r' or '\n'.
+ * The returned buffer needs to be freed by the caller.
+ *
+ * @param buffer the evbuffer to read from
+ * @return pointer to a single line, or NULL if an error occurred
+ */
+char *evbuffer_readline(struct evbuffer *);
+
+
+/**
+  Move data from one evbuffer into another evbuffer.
+
+  This is a destructive add.  The data from one buffer moves into
+  the other buffer. The destination buffer is expanded as needed.
+
+  @param outbuf the output buffer
+  @param inbuf the input buffer
+  @return 0 if successful, or -1 if an error occurred
+ */
+int evbuffer_add_buffer(struct evbuffer *, struct evbuffer *);
+
+
+/**
+  Append a formatted string to the end of an evbuffer.
+
+  @param buf the evbuffer that will be appended to
+  @param fmt a format string
+  @param ... arguments that will be passed to printf(3)
+  @return The number of bytes added if successful, or -1 if an error occurred.
+ */
+int evbuffer_add_printf(struct evbuffer *, const char *fmt, ...)
+#ifdef __GNUC__
+  __attribute__((format(printf, 2, 3)))
+#endif
+;
+
+
+/**
+  Append a va_list formatted string to the end of an evbuffer.
+
+  @param buf the evbuffer that will be appended to
+  @param fmt a format string
+  @param ap a varargs va_list argument array that will be passed to vprintf(3)
+  @return The number of bytes added if successful, or -1 if an error occurred.
+ */
+int evbuffer_add_vprintf(struct evbuffer *, const char *fmt, va_list ap);
+
+
+/**
+  Remove a specified number of bytes data from the beginning of an evbuffer.
+
+  @param buf the evbuffer to be drained
+  @param len the number of bytes to drain from the beginning of the buffer
+  @return 0 if successful, or -1 if an error occurred
+ */
+void evbuffer_drain(struct evbuffer *, size_t);
+
+
+/**
+  Write the contents of an evbuffer to a file descriptor.
+
+  The evbuffer will be drained after the bytes have been successfully written.
+
+  @param buffer the evbuffer to be written and drained
+  @param fd the file descriptor to be written to
+  @return the number of bytes written, or -1 if an error occurred
+  @see evbuffer_read()
+ */
+int evbuffer_write(struct evbuffer *, int);
+
+
+/**
+  Read from a file descriptor and store the result in an evbuffer.
+
+  @param buf the evbuffer to store the result
+  @param fd the file descriptor to read from
+  @param howmuch the number of bytes to be read
+  @return the number of bytes read, or -1 if an error occurred
+  @see evbuffer_write()
+ */
+int evbuffer_read(struct evbuffer *, int, int);
+
+
+/**
+  Find a string within an evbuffer.
+
+  @param buffer the evbuffer to be searched
+  @param what the string to be searched for
+  @param len the length of the search string
+  @return a pointer to the beginning of the search string, or NULL if the search failed.
+ */
+u_char *evbuffer_find(struct evbuffer *, const u_char *, size_t);
+
+/**
+  Set a callback to invoke when the evbuffer is modified.
+
+  @param buffer the evbuffer to be monitored
+  @param cb the callback function to invoke when the evbuffer is modified
+  @param cbarg an argument to be provided to the callback function
+ */
+void evbuffer_setcb(struct evbuffer *, void (*)(struct evbuffer *, size_t, size_t, void *), void *);
+
+/*
+ * Marshaling tagged data - We assume that all tags are inserted in their
+ * numeric order - so that unknown tags will always be higher than the
+ * known ones - and we can just ignore the end of an event buffer.
+ */
+
+void evtag_init(void);
+
+void evtag_marshal(struct evbuffer *evbuf, ev_uint32_t tag, const void *data,
+    ev_uint32_t len);
+
+/**
+  Encode an integer and store it in an evbuffer.
+
+  We encode integer's by nibbles; the first nibble contains the number
+  of significant nibbles - 1;  this allows us to encode up to 64-bit
+  integers.  This function is byte-order independent.
+
+  @param evbuf evbuffer to store the encoded number
+  @param number a 32-bit integer
+ */
+void encode_int(struct evbuffer *evbuf, ev_uint32_t number);
+
+void evtag_marshal_int(struct evbuffer *evbuf, ev_uint32_t tag,
+    ev_uint32_t integer);
+
+void evtag_marshal_string(struct evbuffer *buf, ev_uint32_t tag,
+    const char *string);
+
+void evtag_marshal_timeval(struct evbuffer *evbuf, ev_uint32_t tag,
+    struct timeval *tv);
+
+int evtag_unmarshal(struct evbuffer *src, ev_uint32_t *ptag,
+    struct evbuffer *dst);
+int evtag_peek(struct evbuffer *evbuf, ev_uint32_t *ptag);
+int evtag_peek_length(struct evbuffer *evbuf, ev_uint32_t *plength);
+int evtag_payload_length(struct evbuffer *evbuf, ev_uint32_t *plength);
+int evtag_consume(struct evbuffer *evbuf);
+
+int evtag_unmarshal_int(struct evbuffer *evbuf, ev_uint32_t need_tag,
+    ev_uint32_t *pinteger);
+
+int evtag_unmarshal_fixed(struct evbuffer *src, ev_uint32_t need_tag,
+    void *data, size_t len);
+
+int evtag_unmarshal_string(struct evbuffer *evbuf, ev_uint32_t need_tag,
+    char **pstring);
+
+int evtag_unmarshal_timeval(struct evbuffer *evbuf, ev_uint32_t need_tag,
+    struct timeval *ptv);
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif /* _EVENT_H_ */
diff --git a/libevent/evhttp.h b/libevent/evhttp.h
new file mode 100644
index 0000000..0d35f9e
--- /dev/null
+++ b/libevent/evhttp.h
@@ -0,0 +1,357 @@
+/*
+ * Copyright (c) 2000-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _EVHTTP_H_
+#define _EVHTTP_H_
+
+#include <event.h>
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#ifdef WIN32
+#define WIN32_LEAN_AND_MEAN
+#include <winsock2.h>
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+#endif
+
+/** @file evhttp.h
+ *
+ * Basic support for HTTP serving.
+ *
+ * As libevent is a library for dealing with event notification and most
+ * interesting applications are networked today, I have often found the
+ * need to write HTTP code.  The following prototypes and definitions provide
+ * an application with a minimal interface for making HTTP requests and for
+ * creating a very simple HTTP server.
+ */
+
+/* Response codes */
+#define HTTP_OK			200
+#define HTTP_NOCONTENT		204
+#define HTTP_MOVEPERM		301
+#define HTTP_MOVETEMP		302
+#define HTTP_NOTMODIFIED	304
+#define HTTP_BADREQUEST		400
+#define HTTP_NOTFOUND		404
+#define HTTP_SERVUNAVAIL	503
+
+struct evhttp;
+struct evhttp_request;
+struct evkeyvalq;
+
+/** Create a new HTTP server
+ *
+ * @param base (optional) the event base to receive the HTTP events
+ * @return a pointer to a newly initialized evhttp server structure
+ */
+struct evhttp *evhttp_new(struct event_base *base);
+
+/**
+ * Binds an HTTP server on the specified address and port.
+ *
+ * Can be called multiple times to bind the same http server
+ * to multiple different ports.
+ *
+ * @param http a pointer to an evhttp object
+ * @param address a string containing the IP address to listen(2) on
+ * @param port the port number to listen on
+ * @return a newly allocated evhttp struct
+ * @see evhttp_free()
+ */
+int evhttp_bind_socket(struct evhttp *http, const char *address, u_short port);
+
+/**
+ * Makes an HTTP server accept connections on the specified socket
+ *
+ * This may be useful to create a socket and then fork multiple instances
+ * of an http server, or when a socket has been communicated via file
+ * descriptor passing in situations where an http servers does not have
+ * permissions to bind to a low-numbered port.
+ *
+ * Can be called multiple times to have the http server listen to
+ * multiple different sockets.
+ *
+ * @param http a pointer to an evhttp object
+ * @param fd a socket fd that is ready for accepting connections
+ * @return 0 on success, -1 on failure.
+ * @see evhttp_free(), evhttp_bind_socket()
+ */
+int evhttp_accept_socket(struct evhttp *http, int fd);
+
+/**
+ * Free the previously created HTTP server.
+ *
+ * Works only if no requests are currently being served.
+ *
+ * @param http the evhttp server object to be freed
+ * @see evhttp_start()
+ */
+void evhttp_free(struct evhttp* http);
+
+/** Set a callback for a specified URI */
+void evhttp_set_cb(struct evhttp *, const char *,
+    void (*)(struct evhttp_request *, void *), void *);
+
+/** Removes the callback for a specified URI */
+int evhttp_del_cb(struct evhttp *, const char *);
+
+/** Set a callback for all requests that are not caught by specific callbacks
+ */
+void evhttp_set_gencb(struct evhttp *,
+    void (*)(struct evhttp_request *, void *), void *);
+
+/**
+ * Set the timeout for an HTTP request.
+ *
+ * @param http an evhttp object
+ * @param timeout_in_secs the timeout, in seconds
+ */
+void evhttp_set_timeout(struct evhttp *, int timeout_in_secs);
+
+/* Request/Response functionality */
+
+/**
+ * Send an HTML error message to the client.
+ *
+ * @param req a request object
+ * @param error the HTTP error code
+ * @param reason a brief explanation of the error
+ */
+void evhttp_send_error(struct evhttp_request *req, int error,
+    const char *reason);
+
+/**
+ * Send an HTML reply to the client.
+ *
+ * @param req a request object
+ * @param code the HTTP response code to send
+ * @param reason a brief message to send with the response code
+ * @param databuf the body of the response
+ */
+void evhttp_send_reply(struct evhttp_request *req, int code,
+    const char *reason, struct evbuffer *databuf);
+
+/* Low-level response interface, for streaming/chunked replies */
+void evhttp_send_reply_start(struct evhttp_request *, int, const char *);
+void evhttp_send_reply_chunk(struct evhttp_request *, struct evbuffer *);
+void evhttp_send_reply_end(struct evhttp_request *);
+
+/**
+ * Start an HTTP server on the specified address and port
+ *
+ * DEPRECATED: it does not allow an event base to be specified
+ *
+ * @param address the address to which the HTTP server should be bound
+ * @param port the port number on which the HTTP server should listen
+ * @return an struct evhttp object
+ */
+struct evhttp *evhttp_start(const char *address, u_short port);
+
+/*
+ * Interfaces for making requests
+ */
+enum evhttp_cmd_type { EVHTTP_REQ_GET, EVHTTP_REQ_POST, EVHTTP_REQ_HEAD };
+
+enum evhttp_request_kind { EVHTTP_REQUEST, EVHTTP_RESPONSE };
+
+/**
+ * the request structure that a server receives.
+ * WARNING: expect this structure to change.  I will try to provide
+ * reasonable accessors.
+ */
+struct evhttp_request {
+#if defined(TAILQ_ENTRY)
+	TAILQ_ENTRY(evhttp_request) next;
+#else
+struct {
+	struct evhttp_request *tqe_next;
+	struct evhttp_request **tqe_prev;
+}       next;
+#endif
+
+	/* the connection object that this request belongs to */
+	struct evhttp_connection *evcon;
+	int flags;
+#define EVHTTP_REQ_OWN_CONNECTION	0x0001
+#define EVHTTP_PROXY_REQUEST		0x0002
+
+	struct evkeyvalq *input_headers;
+	struct evkeyvalq *output_headers;
+
+	/* address of the remote host and the port connection came from */
+	char *remote_host;
+	u_short remote_port;
+
+	enum evhttp_request_kind kind;
+	enum evhttp_cmd_type type;
+
+	char *uri;			/* uri after HTTP request was parsed */
+
+	char major;			/* HTTP Major number */
+	char minor;			/* HTTP Minor number */
+
+	int response_code;		/* HTTP Response code */
+	char *response_code_line;	/* Readable response */
+
+	struct evbuffer *input_buffer;	/* read data */
+	ev_int64_t ntoread;
+	int chunked;
+
+	struct evbuffer *output_buffer;	/* outgoing post or data */
+
+	/* Callback */
+	void (*cb)(struct evhttp_request *, void *);
+	void *cb_arg;
+
+	/*
+	 * Chunked data callback - call for each completed chunk if
+	 * specified.  If not specified, all the data is delivered via
+	 * the regular callback.
+	 */
+	void (*chunk_cb)(struct evhttp_request *, void *);
+};
+
+/**
+ * Creates a new request object that needs to be filled in with the request
+ * parameters.  The callback is executed when the request completed or an
+ * error occurred.
+ */
+struct evhttp_request *evhttp_request_new(
+	void (*cb)(struct evhttp_request *, void *), void *arg);
+
+/** enable delivery of chunks to requestor */
+void evhttp_request_set_chunked_cb(struct evhttp_request *,
+    void (*cb)(struct evhttp_request *, void *));
+
+/** Frees the request object and removes associated events. */
+void evhttp_request_free(struct evhttp_request *req);
+
+/**
+ * A connection object that can be used to for making HTTP requests.  The
+ * connection object tries to establish the connection when it is given an
+ * http request object.
+ */
+struct evhttp_connection *evhttp_connection_new(
+	const char *address, unsigned short port);
+
+/** Frees an http connection */
+void evhttp_connection_free(struct evhttp_connection *evcon);
+
+/** sets the ip address from which http connections are made */
+void evhttp_connection_set_local_address(struct evhttp_connection *evcon,
+    const char *address);
+
+/** Sets the timeout for events related to this connection */
+void evhttp_connection_set_timeout(struct evhttp_connection *evcon,
+    int timeout_in_secs);
+
+/** Sets the retry limit for this connection - -1 repeats indefnitely */
+void evhttp_connection_set_retries(struct evhttp_connection *evcon,
+    int retry_max);
+
+/** Set a callback for connection close. */
+void evhttp_connection_set_closecb(struct evhttp_connection *evcon,
+    void (*)(struct evhttp_connection *, void *), void *);
+
+/**
+ * Associates an event base with the connection - can only be called
+ * on a freshly created connection object that has not been used yet.
+ */
+void evhttp_connection_set_base(struct evhttp_connection *evcon,
+    struct event_base *base);
+
+/** Get the remote address and port associated with this connection. */
+void evhttp_connection_get_peer(struct evhttp_connection *evcon,
+    char **address, u_short *port);
+
+/** The connection gets ownership of the request */
+int evhttp_make_request(struct evhttp_connection *evcon,
+    struct evhttp_request *req,
+    enum evhttp_cmd_type type, const char *uri);
+
+const char *evhttp_request_uri(struct evhttp_request *req);
+
+/* Interfaces for dealing with HTTP headers */
+
+const char *evhttp_find_header(const struct evkeyvalq *, const char *);
+int evhttp_remove_header(struct evkeyvalq *, const char *);
+int evhttp_add_header(struct evkeyvalq *, const char *, const char *);
+void evhttp_clear_headers(struct evkeyvalq *);
+
+/* Miscellaneous utility functions */
+
+
+/**
+  Helper function to encode a URI.
+
+  The returned string must be freed by the caller.
+
+  @param uri an unencoded URI
+  @return a newly allocated URI-encoded string
+ */
+char *evhttp_encode_uri(const char *uri);
+
+
+/**
+  Helper function to decode a URI.
+
+  The returned string must be freed by the caller.
+
+  @param uri an encoded URI
+  @return a newly allocated unencoded URI
+ */
+char *evhttp_decode_uri(const char *uri);
+
+
+/**
+ * Helper function to parse out arguments in a query.
+ * The arguments are separated by key and value.
+ * URI should already be decoded.
+ */
+void evhttp_parse_query(const char *uri, struct evkeyvalq *);
+
+
+/**
+ * Escape HTML character entities in a string.
+ *
+ * Replaces <, >, ", ' and & with &lt;, &gt;, &quot;,
+ * &#039; and &amp; correspondingly.
+ *
+ * The returned string needs to be freed by the caller.
+ *
+ * @param html an unescaped HTML string
+ * @return an escaped HTML string
+ */
+char *evhttp_htmlescape(const char *html);
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif /* _EVHTTP_H_ */
diff --git a/libevent/evport.c b/libevent/evport.c
new file mode 100644
index 0000000..31523b4
--- /dev/null
+++ b/libevent/evport.c
@@ -0,0 +1,513 @@
+/*
+ * Submitted by David Pacheco (dp.spambait@gmail.com)
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY SUN MICROSYSTEMS, INC. ``AS IS'' AND ANY
+ * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
+ * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
+ * DISCLAIMED. IN NO EVENT SHALL SUN MICROSYSTEMS, INC. BE LIABLE FOR ANY
+ * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
+ * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
+ * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
+ * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
+ * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
+ */
+
+/*
+ * Copyright (c) 2007 Sun Microsystems. All rights reserved.
+ * Use is subject to license terms.
+ */
+
+/*
+ * evport.c: event backend using Solaris 10 event ports. See port_create(3C).
+ * This implementation is loosely modeled after the one used for select(2) (in
+ * select.c).
+ *
+ * The outstanding events are tracked in a data structure called evport_data.
+ * Each entry in the ed_fds array corresponds to a file descriptor, and contains
+ * pointers to the read and write events that correspond to that fd. (That is,
+ * when the file is readable, the "read" event should handle it, etc.)
+ *
+ * evport_add and evport_del update this data structure. evport_dispatch uses it
+ * to determine where to callback when an event occurs (which it gets from
+ * port_getn). 
+ *
+ * Helper functions are used: grow() grows the file descriptor array as
+ * necessary when large fd's come in. reassociate() takes care of maintaining
+ * the proper file-descriptor/event-port associations.
+ *
+ * As in the select(2) implementation, signals are handled by evsignal.
+ */
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <sys/time.h>
+#include <assert.h>
+#include <sys/queue.h>
+#include <errno.h>
+#include <poll.h>
+#include <port.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <time.h>
+#include <unistd.h>
+#ifdef CHECK_INVARIANTS
+#include <assert.h>
+#endif
+
+#include "event.h"
+#include "event-internal.h"
+#include "log.h"
+#include "evsignal.h"
+
+
+/*
+ * Default value for ed_nevents, which is the maximum file descriptor number we
+ * can handle. If an event comes in for a file descriptor F > nevents, we will
+ * grow the array of file descriptors, doubling its size.
+ */
+#define DEFAULT_NFDS	16
+
+
+/*
+ * EVENTS_PER_GETN is the maximum number of events to retrieve from port_getn on
+ * any particular call. You can speed things up by increasing this, but it will
+ * (obviously) require more memory.
+ */
+#define EVENTS_PER_GETN 8
+
+/*
+ * Per-file-descriptor information about what events we're subscribed to. These
+ * fields are NULL if no event is subscribed to either of them.
+ */
+
+struct fd_info {
+	struct event* fdi_revt; /* the event responsible for the "read"  */
+	struct event* fdi_wevt; /* the event responsible for the "write" */
+};
+
+#define FDI_HAS_READ(fdi)  ((fdi)->fdi_revt != NULL)
+#define FDI_HAS_WRITE(fdi) ((fdi)->fdi_wevt != NULL)
+#define FDI_HAS_EVENTS(fdi) (FDI_HAS_READ(fdi) || FDI_HAS_WRITE(fdi))
+#define FDI_TO_SYSEVENTS(fdi) (FDI_HAS_READ(fdi) ? POLLIN : 0) | \
+    (FDI_HAS_WRITE(fdi) ? POLLOUT : 0)
+
+struct evport_data {
+	int 		ed_port;	/* event port for system events  */
+	int		ed_nevents;	/* number of allocated fdi's 	 */
+	struct fd_info *ed_fds;		/* allocated fdi table 		 */
+	/* fdi's that we need to reassoc */
+	int ed_pending[EVENTS_PER_GETN]; /* fd's with pending events */
+};
+
+static void*	evport_init	(struct event_base *);
+static int 	evport_add	(void *, struct event *);
+static int 	evport_del	(void *, struct event *);
+static int 	evport_dispatch	(struct event_base *, void *, struct timeval *);
+static void	evport_dealloc	(struct event_base *, void *);
+
+const struct eventop evportops = {
+	"event ports",
+	evport_init,
+	evport_add,
+	evport_del,
+	evport_dispatch,
+	evport_dealloc,
+	1 /* need reinit */
+};
+
+/*
+ * Initialize the event port implementation.
+ */
+
+static void*
+evport_init(struct event_base *base)
+{
+	struct evport_data *evpd;
+	int i;
+	/*
+	 * Disable event ports when this environment variable is set 
+	 */
+	if (getenv("EVENT_NOEVPORT"))
+		return (NULL);
+
+	if (!(evpd = calloc(1, sizeof(struct evport_data))))
+		return (NULL);
+
+	if ((evpd->ed_port = port_create()) == -1) {
+		free(evpd);
+		return (NULL);
+	}
+
+	/*
+	 * Initialize file descriptor structure
+	 */
+	evpd->ed_fds = calloc(DEFAULT_NFDS, sizeof(struct fd_info));
+	if (evpd->ed_fds == NULL) {
+		close(evpd->ed_port);
+		free(evpd);
+		return (NULL);
+	}
+	evpd->ed_nevents = DEFAULT_NFDS;
+	for (i = 0; i < EVENTS_PER_GETN; i++)
+		evpd->ed_pending[i] = -1;
+
+	evsignal_init(base);
+
+	return (evpd);
+}
+
+#ifdef CHECK_INVARIANTS
+/*
+ * Checks some basic properties about the evport_data structure. Because it
+ * checks all file descriptors, this function can be expensive when the maximum
+ * file descriptor ever used is rather large.
+ */
+
+static void
+check_evportop(struct evport_data *evpd)
+{
+	assert(evpd);
+	assert(evpd->ed_nevents > 0);
+	assert(evpd->ed_port > 0);
+	assert(evpd->ed_fds > 0);
+
+	/*
+	 * Verify the integrity of the fd_info struct as well as the events to
+	 * which it points (at least, that they're valid references and correct
+	 * for their position in the structure).
+	 */
+	int i;
+	for (i = 0; i < evpd->ed_nevents; ++i) {
+		struct event 	*ev;
+		struct fd_info 	*fdi;
+
+		fdi = &evpd->ed_fds[i];
+		if ((ev = fdi->fdi_revt) != NULL) {
+			assert(ev->ev_fd == i);
+		}
+		if ((ev = fdi->fdi_wevt) != NULL) {
+			assert(ev->ev_fd == i);
+		}
+	}
+}
+
+/*
+ * Verifies very basic integrity of a given port_event.
+ */
+static void
+check_event(port_event_t* pevt)
+{
+	/*
+	 * We've only registered for PORT_SOURCE_FD events. The only
+	 * other thing we can legitimately receive is PORT_SOURCE_ALERT,
+	 * but since we're not using port_alert either, we can assume
+	 * PORT_SOURCE_FD.
+	 */
+	assert(pevt->portev_source == PORT_SOURCE_FD);
+	assert(pevt->portev_user == NULL);
+}
+
+#else
+#define check_evportop(epop)
+#define check_event(pevt)
+#endif /* CHECK_INVARIANTS */
+
+/*
+ * Doubles the size of the allocated file descriptor array.
+ */
+static int
+grow(struct evport_data *epdp, int factor)
+{
+	struct fd_info *tmp;
+	int oldsize = epdp->ed_nevents;
+	int newsize = factor * oldsize;
+	assert(factor > 1);
+
+	check_evportop(epdp);
+
+	tmp = realloc(epdp->ed_fds, sizeof(struct fd_info) * newsize);
+	if (NULL == tmp)
+		return -1;
+	epdp->ed_fds = tmp;
+	memset((char*) (epdp->ed_fds + oldsize), 0, 
+	    (newsize - oldsize)*sizeof(struct fd_info));
+	epdp->ed_nevents = newsize;
+
+	check_evportop(epdp);
+
+	return 0;
+}
+
+
+/*
+ * (Re)associates the given file descriptor with the event port. The OS events
+ * are specified (implicitly) from the fd_info struct.
+ */
+static int
+reassociate(struct evport_data *epdp, struct fd_info *fdip, int fd)
+{
+	int sysevents = FDI_TO_SYSEVENTS(fdip);
+
+	if (sysevents != 0) {
+		if (port_associate(epdp->ed_port, PORT_SOURCE_FD,
+				   fd, sysevents, NULL) == -1) {
+			event_warn("port_associate");
+			return (-1);
+		}
+	}
+
+	check_evportop(epdp);
+
+	return (0);
+}
+
+/*
+ * Main event loop - polls port_getn for some number of events, and processes
+ * them.
+ */
+
+static int
+evport_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	int i, res;
+	struct evport_data *epdp = arg;
+	port_event_t pevtlist[EVENTS_PER_GETN];
+
+	/*
+	 * port_getn will block until it has at least nevents events. It will
+	 * also return how many it's given us (which may be more than we asked
+	 * for, as long as it's less than our maximum (EVENTS_PER_GETN)) in
+	 * nevents.
+	 */
+	int nevents = 1;
+
+	/*
+	 * We have to convert a struct timeval to a struct timespec
+	 * (only difference is nanoseconds vs. microseconds). If no time-based
+	 * events are active, we should wait for I/O (and tv == NULL).
+	 */
+	struct timespec ts;
+	struct timespec *ts_p = NULL;
+	if (tv != NULL) {
+		ts.tv_sec = tv->tv_sec;
+		ts.tv_nsec = tv->tv_usec * 1000;
+		ts_p = &ts;
+	}
+
+	/*
+	 * Before doing anything else, we need to reassociate the events we hit
+	 * last time which need reassociation. See comment at the end of the
+	 * loop below.
+	 */
+	for (i = 0; i < EVENTS_PER_GETN; ++i) {
+		struct fd_info *fdi = NULL;
+		if (epdp->ed_pending[i] != -1) {
+			fdi = &(epdp->ed_fds[epdp->ed_pending[i]]);
+		}
+
+		if (fdi != NULL && FDI_HAS_EVENTS(fdi)) {
+			int fd = FDI_HAS_READ(fdi) ? fdi->fdi_revt->ev_fd : 
+			    fdi->fdi_wevt->ev_fd;
+			reassociate(epdp, fdi, fd);
+			epdp->ed_pending[i] = -1;
+		}
+	}
+
+	if ((res = port_getn(epdp->ed_port, pevtlist, EVENTS_PER_GETN, 
+		    (unsigned int *) &nevents, ts_p)) == -1) {
+		if (errno == EINTR || errno == EAGAIN) {
+			evsignal_process(base);
+			return (0);
+		} else if (errno == ETIME) {
+			if (nevents == 0)
+				return (0);
+		} else {
+			event_warn("port_getn");
+			return (-1);
+		}
+	} else if (base->sig.evsignal_caught) {
+		evsignal_process(base);
+	}
+	
+	event_debug(("%s: port_getn reports %d events", __func__, nevents));
+
+	for (i = 0; i < nevents; ++i) {
+		struct event *ev;
+		struct fd_info *fdi;
+		port_event_t *pevt = &pevtlist[i];
+		int fd = (int) pevt->portev_object;
+
+		check_evportop(epdp);
+		check_event(pevt);
+		epdp->ed_pending[i] = fd;
+
+		/*
+		 * Figure out what kind of event it was 
+		 * (because we have to pass this to the callback)
+		 */
+		res = 0;
+		if (pevt->portev_events & POLLIN)
+			res |= EV_READ;
+		if (pevt->portev_events & POLLOUT)
+			res |= EV_WRITE;
+
+		assert(epdp->ed_nevents > fd);
+		fdi = &(epdp->ed_fds[fd]);
+
+		/*
+		 * We now check for each of the possible events (READ
+		 * or WRITE).  Then, we activate the event (which will
+		 * cause its callback to be executed).
+		 */
+
+		if ((res & EV_READ) && ((ev = fdi->fdi_revt) != NULL)) {
+			event_active(ev, res, 1);
+		}
+
+		if ((res & EV_WRITE) && ((ev = fdi->fdi_wevt) != NULL)) {
+			event_active(ev, res, 1);
+		}
+	} /* end of all events gotten */
+
+	check_evportop(epdp);
+
+	return (0);
+}
+
+
+/*
+ * Adds the given event (so that you will be notified when it happens via
+ * the callback function).
+ */
+
+static int
+evport_add(void *arg, struct event *ev)
+{
+	struct evport_data *evpd = arg;
+	struct fd_info *fdi;
+	int factor;
+
+	check_evportop(evpd);
+
+	/*
+	 * Delegate, if it's not ours to handle.
+	 */
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_add(ev));
+
+	/*
+	 * If necessary, grow the file descriptor info table
+	 */
+
+	factor = 1;
+	while (ev->ev_fd >= factor * evpd->ed_nevents)
+		factor *= 2;
+
+	if (factor > 1) {
+		if (-1 == grow(evpd, factor)) {
+			return (-1);
+		}
+	}
+
+	fdi = &evpd->ed_fds[ev->ev_fd];
+	if (ev->ev_events & EV_READ)
+		fdi->fdi_revt = ev;
+	if (ev->ev_events & EV_WRITE)
+		fdi->fdi_wevt = ev;
+
+	return reassociate(evpd, fdi, ev->ev_fd);
+}
+
+/*
+ * Removes the given event from the list of events to wait for.
+ */
+
+static int
+evport_del(void *arg, struct event *ev)
+{
+	struct evport_data *evpd = arg;
+	struct fd_info *fdi;
+	int i;
+	int associated = 1;
+
+	check_evportop(evpd);
+
+	/*
+	 * Delegate, if it's not ours to handle
+	 */
+	if (ev->ev_events & EV_SIGNAL) {
+		return (evsignal_del(ev));
+	}
+
+	if (evpd->ed_nevents < ev->ev_fd) {
+		return (-1);
+	}
+
+	for (i = 0; i < EVENTS_PER_GETN; ++i) {
+		if (evpd->ed_pending[i] == ev->ev_fd) {
+			associated = 0;
+			break;
+		}
+	}
+
+	fdi = &evpd->ed_fds[ev->ev_fd];
+	if (ev->ev_events & EV_READ)
+		fdi->fdi_revt = NULL;
+	if (ev->ev_events & EV_WRITE)
+		fdi->fdi_wevt = NULL;
+
+	if (associated) {
+		if (!FDI_HAS_EVENTS(fdi) &&
+		    port_dissociate(evpd->ed_port, PORT_SOURCE_FD,
+		    ev->ev_fd) == -1) {	 
+			/*
+			 * Ignre EBADFD error the fd could have been closed
+			 * before event_del() was called.
+			 */
+			if (errno != EBADFD) {
+				event_warn("port_dissociate");
+				return (-1);
+			}
+		} else {
+			if (FDI_HAS_EVENTS(fdi)) {
+				return (reassociate(evpd, fdi, ev->ev_fd));
+			}
+		}
+	} else {
+		if (fdi->fdi_revt == NULL && fdi->fdi_wevt == NULL) {
+			evpd->ed_pending[i] = -1;
+		}
+	}
+	return 0;
+}
+
+
+static void
+evport_dealloc(struct event_base *base, void *arg)
+{
+	struct evport_data *evpd = arg;
+
+	evsignal_dealloc(base);
+
+	close(evpd->ed_port);
+
+	if (evpd->ed_fds)
+		free(evpd->ed_fds);
+	free(evpd);
+}
diff --git a/libevent/evsignal.h b/libevent/evsignal.h
new file mode 100644
index 0000000..8be9cbd
--- /dev/null
+++ b/libevent/evsignal.h
@@ -0,0 +1,52 @@
+/*
+ * Copyright 2000-2002 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _EVSIGNAL_H_
+#define _EVSIGNAL_H_
+
+typedef void (*ev_sighandler_t)(int);
+
+struct evsignal_info {
+	struct event ev_signal;
+	int ev_signal_pair[2];
+	int ev_signal_added;
+	volatile sig_atomic_t evsignal_caught;
+	struct event_list evsigevents[NSIG];
+	sig_atomic_t evsigcaught[NSIG];
+#ifdef HAVE_SIGACTION
+	struct sigaction **sh_old;
+#else
+	ev_sighandler_t **sh_old;
+#endif
+	int sh_old_max;
+};
+void evsignal_init(struct event_base *);
+void evsignal_process(struct event_base *);
+int evsignal_add(struct event *);
+int evsignal_del(struct event *);
+void evsignal_dealloc(struct event_base *);
+
+#endif /* _EVSIGNAL_H_ */
diff --git a/libevent/evutil.c b/libevent/evutil.c
new file mode 100644
index 0000000..86205b2
--- /dev/null
+++ b/libevent/evutil.c
@@ -0,0 +1,248 @@
+/*
+ * Copyright (c) 2007 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#include "event-fpm.h"
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef WIN32
+#include <winsock2.h>
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+#endif
+
+#include <sys/types.h>
+#ifdef HAVE_SYS_SOCKET_H
+#include <sys/socket.h>
+#endif
+#ifdef HAVE_UNISTD_H
+#include <unistd.h>
+#endif
+#ifdef HAVE_FCNTL_H
+#include <fcntl.h>
+#endif
+#ifdef HAVE_STDLIB_H
+#include <stdlib.h>
+#endif
+#include <errno.h>
+#if defined WIN32 && !defined(HAVE_GETTIMEOFDAY_H)
+#include <sys/timeb.h>
+#endif
+#include <stdio.h>
+
+#include "evutil.h"
+#include "log.h"
+
+int
+evutil_socketpair(int family, int type, int protocol, int fd[2])
+{
+#ifndef WIN32
+	return socketpair(family, type, protocol, fd);
+#else
+	/* This code is originally from Tor.  Used with permission. */
+
+	/* This socketpair does not work when localhost is down. So
+	 * it's really not the same thing at all. But it's close enough
+	 * for now, and really, when localhost is down sometimes, we
+	 * have other problems too.
+	 */
+	int listener = -1;
+	int connector = -1;
+	int acceptor = -1;
+	struct sockaddr_in listen_addr;
+	struct sockaddr_in connect_addr;
+	int size;
+	int saved_errno = -1;
+
+	if (protocol
+#ifdef AF_UNIX
+		|| family != AF_UNIX
+#endif
+		) {
+		EVUTIL_SET_SOCKET_ERROR(WSAEAFNOSUPPORT);
+		return -1;
+	}
+	if (!fd) {
+		EVUTIL_SET_SOCKET_ERROR(WSAEINVAL);
+		return -1;
+	}
+
+	listener = socket(AF_INET, type, 0);
+	if (listener < 0)
+		return -1;
+	memset(&listen_addr, 0, sizeof(listen_addr));
+	listen_addr.sin_family = AF_INET;
+	listen_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
+	listen_addr.sin_port = 0;	/* kernel chooses port.	 */
+	if (bind(listener, (struct sockaddr *) &listen_addr, sizeof (listen_addr))
+		== -1)
+		goto tidy_up_and_fail;
+	if (listen(listener, 1) == -1)
+		goto tidy_up_and_fail;
+
+	connector = socket(AF_INET, type, 0);
+	if (connector < 0)
+		goto tidy_up_and_fail;
+	/* We want to find out the port number to connect to.  */
+	size = sizeof(connect_addr);
+	if (getsockname(listener, (struct sockaddr *) &connect_addr, &size) == -1)
+		goto tidy_up_and_fail;
+	if (size != sizeof (connect_addr))
+		goto abort_tidy_up_and_fail;
+	if (connect(connector, (struct sockaddr *) &connect_addr,
+				sizeof(connect_addr)) == -1)
+		goto tidy_up_and_fail;
+
+	size = sizeof(listen_addr);
+	acceptor = accept(listener, (struct sockaddr *) &listen_addr, &size);
+	if (acceptor < 0)
+		goto tidy_up_and_fail;
+	if (size != sizeof(listen_addr))
+		goto abort_tidy_up_and_fail;
+	EVUTIL_CLOSESOCKET(listener);
+	/* Now check we are talking to ourself by matching port and host on the
+	   two sockets.	 */
+	if (getsockname(connector, (struct sockaddr *) &connect_addr, &size) == -1)
+		goto tidy_up_and_fail;
+	if (size != sizeof (connect_addr)
+		|| listen_addr.sin_family != connect_addr.sin_family
+		|| listen_addr.sin_addr.s_addr != connect_addr.sin_addr.s_addr
+		|| listen_addr.sin_port != connect_addr.sin_port)
+		goto abort_tidy_up_and_fail;
+	fd[0] = connector;
+	fd[1] = acceptor;
+
+	return 0;
+
+ abort_tidy_up_and_fail:
+	saved_errno = WSAECONNABORTED;
+ tidy_up_and_fail:
+	if (saved_errno < 0)
+		saved_errno = WSAGetLastError();
+	if (listener != -1)
+		EVUTIL_CLOSESOCKET(listener);
+	if (connector != -1)
+		EVUTIL_CLOSESOCKET(connector);
+	if (acceptor != -1)
+		EVUTIL_CLOSESOCKET(acceptor);
+
+	EVUTIL_SET_SOCKET_ERROR(saved_errno);
+	return -1;
+#endif
+}
+
+int
+evutil_make_socket_nonblocking(int fd)
+{
+#ifdef WIN32
+	{
+		unsigned long nonblocking = 1;
+		ioctlsocket(fd, FIONBIO, (unsigned long*) &nonblocking);
+	}
+#else
+	if (fcntl(fd, F_SETFL, O_NONBLOCK) == -1) {
+		event_warn("fcntl(O_NONBLOCK)");
+		return -1;
+}	
+#endif
+	return 0;
+}
+
+ev_int64_t
+evutil_strtoll(const char *s, char **endptr, int base)
+{
+#ifdef HAVE_STRTOLL
+	return (ev_int64_t)strtoll(s, endptr, base);
+#elif SIZEOF_LONG == 8
+	return (ev_int64_t)strtol(s, endptr, base);
+#elif defined(WIN32) && defined(_MSC_VER) && _MSC_VER < 1300
+	/* XXXX on old versions of MS APIs, we only support base
+	 * 10. */
+	ev_int64_t r;
+	if (base != 10)
+		return 0;
+	r = (ev_int64_t) _atoi64(s);
+	while (isspace(*s))
+		++s;
+	while (isdigit(*s))
+		++s;
+	if (endptr)
+		*endptr = (char*) s;
+	return r;
+#elif defined(WIN32)
+	return (ev_int64_t) _strtoi64(s, endptr, base);
+#else
+#error "I don't know how to parse 64-bit integers."
+#endif
+}
+
+#ifndef _EVENT_HAVE_GETTIMEOFDAY
+int
+evutil_gettimeofday(struct timeval *tv, struct timezone *tz)
+{
+	struct _timeb tb;
+
+	if(tv == NULL)
+		return -1;
+
+	_ftime(&tb);
+	tv->tv_sec = (long) tb.time;
+	tv->tv_usec = ((int) tb.millitm) * 1000;
+	return 0;
+}
+#endif
+
+int
+evutil_snprintf(char *buf, size_t buflen, const char *format, ...)
+{
+	int r;
+	va_list ap;
+	va_start(ap, format);
+	r = evutil_vsnprintf(buf, buflen, format, ap);
+	va_end(ap);
+	return r;
+}
+
+int
+evutil_vsnprintf(char *buf, size_t buflen, const char *format, va_list ap)
+{
+#ifdef _MSC_VER
+	int r = _vsnprintf(buf, buflen, format, ap);
+	buf[buflen-1] = '\0';
+	if (r >= 0)
+		return r;
+	else
+		return _vscprintf(format, ap);
+#else
+	int r = vsnprintf(buf, buflen, format, ap);
+	buf[buflen-1] = '\0';
+	return r;
+#endif
+}
diff --git a/libevent/evutil.h b/libevent/evutil.h
new file mode 100644
index 0000000..0a018b8
--- /dev/null
+++ b/libevent/evutil.h
@@ -0,0 +1,185 @@
+/*
+ * Copyright (c) 2007 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _EVUTIL_H_
+#define _EVUTIL_H_
+
+/** @file evutil.h
+
+  Common convenience functions for cross-platform portability and
+  related socket manipulations.
+
+ */
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#include <event-config.h>
+#ifdef _EVENT_HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+#ifdef _EVENT_HAVE_STDINT_H
+#include <stdint.h>
+#elif defined(_EVENT_HAVE_INTTYPES_H)
+#include <inttypes.h>
+#endif
+#ifdef _EVENT_HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+#include <stdarg.h>
+
+#ifdef _EVENT_HAVE_UINT64_T
+#define ev_uint64_t uint64_t
+#define ev_int64_t int64_t
+#elif defined(WIN32)
+#define ev_uint64_t unsigned __int64
+#define ev_int64_t signed __int64
+#elif _EVENT_SIZEOF_LONG_LONG == 8
+#define ev_uint64_t unsigned long long
+#define ev_int64_t long long
+#elif _EVENT_SIZEOF_LONG == 8
+#define ev_uint64_t unsigned long
+#define ev_int64_t long
+#else
+#error "No way to define ev_uint64_t"
+#endif
+
+#ifdef _EVENT_HAVE_UINT32_T
+#define ev_uint32_t uint32_t
+#elif defined(WIN32)
+#define ev_uint32_t unsigned int
+#elif _EVENT_SIZEOF_LONG == 4
+#define ev_uint32_t unsigned long
+#elif _EVENT_SIZEOF_INT == 4
+#define ev_uint32_t unsigned int
+#else
+#error "No way to define ev_uint32_t"
+#endif
+
+#ifdef _EVENT_HAVE_UINT16_T
+#define ev_uint16_t uint16_t
+#elif defined(WIN32)
+#define ev_uint16_t unsigned short
+#elif _EVENT_SIZEOF_INT == 2
+#define ev_uint16_t unsigned int
+#elif _EVENT_SIZEOF_SHORT == 2
+#define ev_uint16_t unsigned short
+#else
+#error "No way to define ev_uint16_t"
+#endif
+
+#ifdef _EVENT_HAVE_UINT8_T
+#define ev_uint8_t uint8_t
+#else
+#define ev_uint8_t unsigned char
+#endif
+
+int evutil_socketpair(int d, int type, int protocol, int sv[2]);
+int evutil_make_socket_nonblocking(int sock);
+#ifdef WIN32
+#define EVUTIL_CLOSESOCKET(s) closesocket(s)
+#else
+#define EVUTIL_CLOSESOCKET(s) close(s)
+#endif
+
+#ifdef WIN32
+#define EVUTIL_SOCKET_ERROR() WSAGetLastError()
+#define EVUTIL_SET_SOCKET_ERROR(errcode)		\
+	do { WSASetLastError(errcode); } while (0)
+#else
+#define EVUTIL_SOCKET_ERROR() (errno)
+#define EVUTIL_SET_SOCKET_ERROR(errcode)		\
+		do { errno = (errcode); } while (0)
+#endif
+
+/*
+ * Manipulation functions for struct timeval
+ */
+#ifdef _EVENT_HAVE_TIMERADD
+#define evutil_timeradd(tvp, uvp, vvp) timeradd((tvp), (uvp), (vvp))
+#define evutil_timersub(tvp, uvp, vvp) timersub((tvp), (uvp), (vvp))
+#else
+#define evutil_timeradd(tvp, uvp, vvp)							\
+	do {														\
+		(vvp)->tv_sec = (tvp)->tv_sec + (uvp)->tv_sec;			\
+		(vvp)->tv_usec = (tvp)->tv_usec + (uvp)->tv_usec;       \
+		if ((vvp)->tv_usec >= 1000000) {						\
+			(vvp)->tv_sec++;									\
+			(vvp)->tv_usec -= 1000000;							\
+		}														\
+	} while (0)
+#define	evutil_timersub(tvp, uvp, vvp)						\
+	do {													\
+		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec < 0) {							\
+			(vvp)->tv_sec--;								\
+			(vvp)->tv_usec += 1000000;						\
+		}													\
+	} while (0)
+#endif /* !_EVENT_HAVE_HAVE_TIMERADD */
+
+#ifdef _EVENT_HAVE_TIMERCLEAR
+#define evutil_timerclear(tvp) timerclear(tvp)
+#else
+#define	evutil_timerclear(tvp)	(tvp)->tv_sec = (tvp)->tv_usec = 0
+#endif
+
+#define	evutil_timercmp(tvp, uvp, cmp)							\
+	(((tvp)->tv_sec == (uvp)->tv_sec) ?							\
+	 ((tvp)->tv_usec cmp (uvp)->tv_usec) :						\
+	 ((tvp)->tv_sec cmp (uvp)->tv_sec))
+
+#ifdef _EVENT_HAVE_TIMERISSET
+#define evutil_timerisset(tvp) timerisset(tvp)
+#else
+#define	evutil_timerisset(tvp)	((tvp)->tv_sec || (tvp)->tv_usec)
+#endif
+
+
+/* big-int related functions */
+ev_int64_t evutil_strtoll(const char *s, char **endptr, int base);
+
+
+#ifdef _EVENT_HAVE_GETTIMEOFDAY
+#define evutil_gettimeofday(tv, tz) gettimeofday((tv), (tz))
+#else
+int evutil_gettimeofday(struct timeval *tv, struct timezone *tz);
+#endif
+
+int evutil_snprintf(char *buf, size_t buflen, const char *format, ...)
+#ifdef __GNUC__
+	__attribute__((format(printf, 3, 4)))
+#endif
+	;
+int evutil_vsnprintf(char *buf, size_t buflen, const char *format, va_list ap);
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif /* _EVUTIL_H_ */
diff --git a/libevent/http-internal.h b/libevent/http-internal.h
new file mode 100644
index 0000000..bc9a1ed
--- /dev/null
+++ b/libevent/http-internal.h
@@ -0,0 +1,153 @@
+/*
+ * Copyright 2001 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * This header file contains definitions for dealing with HTTP requests
+ * that are internal to libevent.  As user of the library, you should not
+ * need to know about these.
+ */
+
+#ifndef _HTTP_H_
+#define _HTTP_H_
+
+#define HTTP_CONNECT_TIMEOUT	45
+#define HTTP_WRITE_TIMEOUT	50
+#define HTTP_READ_TIMEOUT	50
+
+#define HTTP_PREFIX		"http://"
+#define HTTP_DEFAULTPORT	80
+
+enum message_read_status {
+	ALL_DATA_READ = 1,
+	MORE_DATA_EXPECTED = 0,
+	DATA_CORRUPTED = -1,
+	REQUEST_CANCELED = -2
+};
+
+enum evhttp_connection_error {
+	EVCON_HTTP_TIMEOUT,
+	EVCON_HTTP_EOF,
+	EVCON_HTTP_INVALID_HEADER
+};
+
+struct evbuffer;
+struct addrinfo;
+struct evhttp_request;
+
+/* A stupid connection object - maybe make this a bufferevent later */
+
+enum evhttp_connection_state {
+	EVCON_DISCONNECTED,	/**< not currently connected not trying either*/
+	EVCON_CONNECTING,	/**< tries to currently connect */
+	EVCON_IDLE,		/**< connection is established */
+	EVCON_READING_FIRSTLINE,/**< reading Request-Line (incoming conn) or
+				 **< Status-Line (outgoing conn) */
+	EVCON_READING_HEADERS,	/**< reading request/response headers */
+	EVCON_READING_BODY,	/**< reading request/response body */
+	EVCON_READING_TRAILER,	/**< reading request/response chunked trailer */
+	EVCON_WRITING		/**< writing request/response headers/body */
+};
+
+struct event_base;
+
+struct evhttp_connection {
+	/* we use tailq only if they were created for an http server */
+	TAILQ_ENTRY(evhttp_connection) (next);
+
+	int fd;
+	struct event ev;
+	struct event close_ev;
+	struct evbuffer *input_buffer;
+	struct evbuffer *output_buffer;
+	
+	char *bind_address;		/* address to use for binding the src */
+
+	char *address;			/* address to connect to */
+	u_short port;
+
+	int flags;
+#define EVHTTP_CON_INCOMING	0x0001	/* only one request on it ever */
+#define EVHTTP_CON_OUTGOING	0x0002  /* multiple requests possible */
+#define EVHTTP_CON_CLOSEDETECT  0x0004  /* detecting if persistent close */
+
+	int timeout;			/* timeout in seconds for events */
+	int retry_cnt;			/* retry count */
+	int retry_max;			/* maximum number of retries */
+	
+	enum evhttp_connection_state state;
+
+	/* for server connections, the http server they are connected with */
+	struct evhttp *http_server;
+
+	TAILQ_HEAD(evcon_requestq, evhttp_request) requests;
+	
+						   void (*cb)(struct evhttp_connection *, void *);
+	void *cb_arg;
+	
+	void (*closecb)(struct evhttp_connection *, void *);
+	void *closecb_arg;
+
+	struct event_base *base;
+};
+
+struct evhttp_cb {
+	TAILQ_ENTRY(evhttp_cb) next;
+
+	char *what;
+
+	void (*cb)(struct evhttp_request *req, void *);
+	void *cbarg;
+};
+
+/* both the http server as well as the rpc system need to queue connections */
+TAILQ_HEAD(evconq, evhttp_connection);
+
+/* each bound socket is stored in one of these */
+struct evhttp_bound_socket {
+	TAILQ_ENTRY(evhttp_bound_socket) (next);
+
+	struct event  bind_ev;
+};
+
+struct evhttp {
+	TAILQ_HEAD(boundq, evhttp_bound_socket) sockets;
+
+	TAILQ_HEAD(httpcbq, evhttp_cb) callbacks;
+        struct evconq connections;
+
+        int timeout;
+
+	void (*gencb)(struct evhttp_request *req, void *);
+	void *gencbarg;
+
+	struct event_base *base;
+};
+
+/* resets the connection; can be reused for more requests */
+void evhttp_connection_reset(struct evhttp_connection *);
+
+/* connects if necessary */
+int evhttp_connection_connect(struct evhttp_connection *);
+
+/* notifies the current request that it failed; resets connection */
+void evhttp_connection_fail(struct evhttp_connection *,
+    enum evhttp_connection_error error);
+
+void evhttp_get_request(struct evhttp *, int, struct sockaddr *, socklen_t);
+
+int evhttp_hostportfile(char *, char **, u_short *, char **);
+
+int evhttp_parse_firstline(struct evhttp_request *, struct evbuffer*);
+int evhttp_parse_headers(struct evhttp_request *, struct evbuffer*);
+
+void evhttp_start_read(struct evhttp_connection *);
+void evhttp_make_header(struct evhttp_connection *, struct evhttp_request *);
+
+void evhttp_write_buffer(struct evhttp_connection *,
+    void (*)(struct evhttp_connection *, void *), void *);
+
+/* response sending HTML the data in the buffer */
+void evhttp_response_code(struct evhttp_request *, int, const char *);
+void evhttp_send_page(struct evhttp_request *, struct evbuffer *);
+
+#endif /* _HTTP_H */
diff --git a/libevent/http.c b/libevent/http.c
new file mode 100644
index 0000000..1d60fc5
--- /dev/null
+++ b/libevent/http.c
@@ -0,0 +1,2768 @@
+/*
+ * Copyright (c) 2002-2006 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef HAVE_SYS_PARAM_H
+#include <sys/param.h>
+#endif
+#ifdef HAVE_SYS_TYPES_H
+#include <sys/types.h>
+#endif
+
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+#ifdef HAVE_SYS_IOCCOM_H
+#include <sys/ioccom.h>
+#endif
+
+#ifndef WIN32
+#include <sys/resource.h>
+#include <sys/socket.h>
+#include <sys/stat.h>
+#include <sys/wait.h>
+#endif
+
+#include <sys/queue.h>
+
+#ifndef WIN32
+#include <netinet/in.h>
+#include <netdb.h>
+#endif
+
+#ifdef WIN32
+#include <winsock2.h>
+#endif
+
+#include <assert.h>
+#include <ctype.h>
+#include <errno.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#ifndef WIN32
+#include <syslog.h>
+#endif
+#include <signal.h>
+#include <time.h>
+#ifdef HAVE_UNISTD_H
+#include <unistd.h>
+#endif
+#ifdef HAVE_FCNTL_H
+#include <fcntl.h>
+#endif
+
+#undef timeout_pending
+#undef timeout_initialized
+
+#include "strlcpy-internal.h"
+#include "event.h"
+#include "evhttp.h"
+#include "evutil.h"
+#include "log.h"
+#include "http-internal.h"
+
+#ifdef WIN32
+#define strcasecmp _stricmp
+#define strncasecmp _strnicmp
+#define strdup _strdup
+#endif
+
+#ifndef HAVE_GETNAMEINFO
+#define NI_MAXSERV 32
+#define NI_MAXHOST 1025
+
+#define NI_NUMERICHOST 1
+#define NI_NUMERICSERV 2
+
+int
+fake_getnameinfo(const struct sockaddr *sa, size_t salen, char *host, 
+	size_t hostlen, char *serv, size_t servlen, int flags)
+{
+        struct sockaddr_in *sin = (struct sockaddr_in *)sa;
+        
+        if (serv != NULL) {
+				char tmpserv[16];
+				evutil_snprintf(tmpserv, sizeof(tmpserv),
+					"%d", ntohs(sin->sin_port));
+                if (strlcpy(serv, tmpserv, servlen) >= servlen)
+                        return (-1);
+        }
+
+        if (host != NULL) {
+                if (flags & NI_NUMERICHOST) {
+                        if (strlcpy(host, inet_ntoa(sin->sin_addr),
+                            hostlen) >= hostlen)
+                                return (-1);
+                        else
+                                return (0);
+                } else {
+						struct hostent *hp;
+                        hp = gethostbyaddr((char *)&sin->sin_addr, 
+                            sizeof(struct in_addr), AF_INET);
+                        if (hp == NULL)
+                                return (-2);
+                        
+                        if (strlcpy(host, hp->h_name, hostlen) >= hostlen)
+                                return (-1);
+                        else
+                                return (0);
+                }
+        }
+        return (0);
+}
+
+#endif
+
+#ifndef HAVE_GETADDRINFO
+struct addrinfo {
+	int ai_family;
+	int ai_socktype;
+	int ai_protocol;
+	size_t ai_addrlen;
+	struct sockaddr *ai_addr;
+	struct addrinfo *ai_next;
+};
+static int
+fake_getaddrinfo(const char *hostname, struct addrinfo *ai)
+{
+	struct hostent *he = NULL;
+	struct sockaddr_in *sa;
+	if (hostname) {
+		he = gethostbyname(hostname);
+		if (!he)
+			return (-1);
+	}
+	ai->ai_family = he ? he->h_addrtype : AF_INET;
+	ai->ai_socktype = SOCK_STREAM;
+	ai->ai_protocol = 0;
+	ai->ai_addrlen = sizeof(struct sockaddr_in);
+	if (NULL == (ai->ai_addr = malloc(ai->ai_addrlen)))
+		return (-1);
+	sa = (struct sockaddr_in*)ai->ai_addr;
+	memset(sa, 0, ai->ai_addrlen);
+	if (he) {
+		sa->sin_family = he->h_addrtype;
+		memcpy(&sa->sin_addr, he->h_addr_list[0], he->h_length);
+	} else {
+		sa->sin_family = AF_INET;
+		sa->sin_addr.s_addr = INADDR_ANY;
+	}
+	ai->ai_next = NULL;
+	return (0);
+}
+static void
+fake_freeaddrinfo(struct addrinfo *ai)
+{
+	free(ai->ai_addr);
+}
+#endif
+
+#ifndef MIN
+#define MIN(a,b) (((a)<(b))?(a):(b))
+#endif
+
+/* wrapper for setting the base from the http server */
+#define EVHTTP_BASE_SET(x, y) do { \
+	if ((x)->base != NULL) event_base_set((x)->base, y);	\
+} while (0) 
+
+extern int debug;
+
+static int socket_connect(int fd, const char *address, unsigned short port);
+static int bind_socket_ai(struct addrinfo *, int reuse);
+static int bind_socket(const char *, u_short, int reuse);
+static void name_from_addr(struct sockaddr *, socklen_t, char **, char **);
+static int evhttp_associate_new_request_with_connection(
+	struct evhttp_connection *evcon);
+static void evhttp_connection_start_detectclose(
+	struct evhttp_connection *evcon);
+static void evhttp_connection_stop_detectclose(
+	struct evhttp_connection *evcon);
+static void evhttp_request_dispatch(struct evhttp_connection* evcon);
+static void evhttp_read_firstline(struct evhttp_connection *evcon,
+				  struct evhttp_request *req);
+static void evhttp_read_header(struct evhttp_connection *evcon,
+    struct evhttp_request *req);
+
+void evhttp_read(int, short, void *);
+void evhttp_write(int, short, void *);
+
+#ifndef HAVE_STRSEP
+/* strsep replacement for platforms that lack it.  Only works if
+ * del is one character long. */
+static char *
+strsep(char **s, const char *del)
+{
+	char *d, *tok;
+	assert(strlen(del) == 1);
+	if (!s || !*s)
+		return NULL;
+	tok = *s;
+	d = strstr(tok, del);
+	if (d) {
+		*d = '\0';
+		*s = d + 1;
+	} else
+		*s = NULL;
+	return tok;
+}
+#endif
+
+static const char *
+html_replace(char ch, char *buf)
+{
+	switch (ch) {
+	case '<':
+		return "&lt;";
+	case '>':
+		return "&gt;";
+	case '"':
+		return "&quot;";
+	case '\'':
+		return "&#039;";
+	case '&':
+		return "&amp;";
+	default:
+		break;
+	}
+
+	/* Echo the character back */
+	buf[0] = ch;
+	buf[1] = '\0';
+	
+	return buf;
+}
+
+/*
+ * Replaces <, >, ", ' and & with &lt;, &gt;, &quot;,
+ * &#039; and &amp; correspondingly.
+ *
+ * The returned string needs to be freed by the caller.
+ */
+
+char *
+evhttp_htmlescape(const char *html)
+{
+	int i, new_size = 0, old_size = strlen(html);
+	char *escaped_html, *p;
+	char scratch_space[2];
+	
+	for (i = 0; i < old_size; ++i)
+          new_size += strlen(html_replace(html[i], scratch_space));
+
+	p = escaped_html = malloc(new_size + 1);
+	if (escaped_html == NULL)
+		event_err(1, "%s: malloc(%d)", __func__, new_size + 1);
+	for (i = 0; i < old_size; ++i) {
+		const char *replaced = html_replace(html[i], scratch_space);
+		/* this is length checked */
+		strcpy(p, replaced);
+		p += strlen(replaced);
+	}
+
+	*p = '\0';
+
+	return (escaped_html);
+}
+
+static const char *
+evhttp_method(enum evhttp_cmd_type type)
+{
+	const char *method;
+
+	switch (type) {
+	case EVHTTP_REQ_GET:
+		method = "GET";
+		break;
+	case EVHTTP_REQ_POST:
+		method = "POST";
+		break;
+	case EVHTTP_REQ_HEAD:
+		method = "HEAD";
+		break;
+	default:
+		method = NULL;
+		break;
+	}
+
+	return (method);
+}
+
+static void
+evhttp_add_event(struct event *ev, int timeout, int default_timeout)
+{
+	if (timeout != 0) {
+		struct timeval tv;
+		
+		evutil_timerclear(&tv);
+		tv.tv_sec = timeout != -1 ? timeout : default_timeout;
+		event_add(ev, &tv);
+	} else {
+		event_add(ev, NULL);
+	}
+}
+
+void
+evhttp_write_buffer(struct evhttp_connection *evcon,
+    void (*cb)(struct evhttp_connection *, void *), void *arg)
+{
+	event_debug(("%s: preparing to write buffer\n", __func__));
+
+	/* Set call back */
+	evcon->cb = cb;
+	evcon->cb_arg = arg;
+
+	/* check if the event is already pending */
+	if (event_pending(&evcon->ev, EV_WRITE|EV_TIMEOUT, NULL))
+		event_del(&evcon->ev);
+
+	event_set(&evcon->ev, evcon->fd, EV_WRITE, evhttp_write, evcon);
+	EVHTTP_BASE_SET(evcon, &evcon->ev);
+	evhttp_add_event(&evcon->ev, evcon->timeout, HTTP_WRITE_TIMEOUT);
+}
+
+static int
+evhttp_connected(struct evhttp_connection *evcon)
+{
+	switch (evcon->state) {
+	case EVCON_DISCONNECTED:
+	case EVCON_CONNECTING:
+		return (0);
+	case EVCON_IDLE:
+	case EVCON_READING_FIRSTLINE:
+	case EVCON_READING_HEADERS:
+	case EVCON_READING_BODY:
+	case EVCON_READING_TRAILER:
+	case EVCON_WRITING:
+	default:
+		return (1);
+	}
+}
+
+/*
+ * Create the headers needed for an HTTP request
+ */
+static void
+evhttp_make_header_request(struct evhttp_connection *evcon,
+    struct evhttp_request *req)
+{
+	char line[1024];
+	const char *method;
+	
+	evhttp_remove_header(req->output_headers, "Proxy-Connection");
+
+	/* Generate request line */
+	method = evhttp_method(req->type);
+	evutil_snprintf(line, sizeof(line), "%s %s HTTP/%d.%d\r\n",
+	    method, req->uri, req->major, req->minor);
+	evbuffer_add(evcon->output_buffer, line, strlen(line));
+
+	/* Add the content length on a post request if missing */
+	if (req->type == EVHTTP_REQ_POST &&
+	    evhttp_find_header(req->output_headers, "Content-Length") == NULL){
+		char size[12];
+		evutil_snprintf(size, sizeof(size), "%ld",
+		    (long)EVBUFFER_LENGTH(req->output_buffer));
+		evhttp_add_header(req->output_headers, "Content-Length", size);
+	}
+}
+
+static int
+evhttp_is_connection_close(int flags, struct evkeyvalq* headers)
+{
+	if (flags & EVHTTP_PROXY_REQUEST) {
+		/* proxy connection */
+		const char *connection = evhttp_find_header(headers, "Proxy-Connection");
+		return (connection == NULL || strcasecmp(connection, "keep-alive") != 0);
+	} else {
+		const char *connection = evhttp_find_header(headers, "Connection");
+		return (connection != NULL && strcasecmp(connection, "close") == 0);
+	}
+}
+
+static int
+evhttp_is_connection_keepalive(struct evkeyvalq* headers)
+{
+	const char *connection = evhttp_find_header(headers, "Connection");
+	return (connection != NULL 
+	    && strncasecmp(connection, "keep-alive", 10) == 0);
+}
+
+static void
+evhttp_maybe_add_date_header(struct evkeyvalq *headers)
+{
+	if (evhttp_find_header(headers, "Date") == NULL) {
+		char date[50];
+#ifndef WIN32
+		struct tm cur;
+#endif
+		struct tm *cur_p;
+		time_t t = time(NULL);
+#ifdef WIN32
+		cur_p = gmtime(&t);
+#else
+		gmtime_r(&t, &cur);
+		cur_p = &cur;
+#endif
+		if (strftime(date, sizeof(date),
+			"%a, %d %b %Y %H:%M:%S GMT", cur_p) != 0) {
+			evhttp_add_header(headers, "Date", date);
+		}
+	}
+}
+
+static void
+evhttp_maybe_add_content_length_header(struct evkeyvalq *headers,
+    long content_length)
+{
+	if (evhttp_find_header(headers, "Transfer-Encoding") == NULL &&
+	    evhttp_find_header(headers,	"Content-Length") == NULL) {
+		char len[12];
+		evutil_snprintf(len, sizeof(len), "%ld", content_length);
+		evhttp_add_header(headers, "Content-Length", len);
+	}
+}
+
+/*
+ * Create the headers needed for an HTTP reply
+ */
+
+static void
+evhttp_make_header_response(struct evhttp_connection *evcon,
+    struct evhttp_request *req)
+{
+	int is_keepalive = evhttp_is_connection_keepalive(req->input_headers);
+	char line[1024];
+	evutil_snprintf(line, sizeof(line), "HTTP/%d.%d %d %s\r\n",
+	    req->major, req->minor, req->response_code,
+	    req->response_code_line);
+	evbuffer_add(evcon->output_buffer, line, strlen(line));
+
+	if (req->major == 1) {
+		if (req->minor == 1)
+			evhttp_maybe_add_date_header(req->output_headers);
+
+		/*
+		 * if the protocol is 1.0; and the connection was keep-alive
+		 * we need to add a keep-alive header, too.
+		 */
+		if (req->minor == 0 && is_keepalive)
+			evhttp_add_header(req->output_headers,
+			    "Connection", "keep-alive");
+
+		if (req->minor == 1 || is_keepalive) {
+			/* 
+			 * we need to add the content length if the
+			 * user did not give it, this is required for
+			 * persistent connections to work.
+			 */
+			evhttp_maybe_add_content_length_header(
+				req->output_headers,
+				(long)EVBUFFER_LENGTH(req->output_buffer));
+		}
+	}
+
+	/* Potentially add headers for unidentified content. */
+	if (EVBUFFER_LENGTH(req->output_buffer)) {
+		if (evhttp_find_header(req->output_headers,
+			"Content-Type") == NULL) {
+			evhttp_add_header(req->output_headers,
+			    "Content-Type", "text/html; charset=ISO-8859-1");
+		}
+	}
+
+	/* if the request asked for a close, we send a close, too */
+	if (evhttp_is_connection_close(req->flags, req->input_headers)) {
+		evhttp_remove_header(req->output_headers, "Connection");
+		if (!(req->flags & EVHTTP_PROXY_REQUEST))
+		    evhttp_add_header(req->output_headers, "Connection", "close");
+		evhttp_remove_header(req->output_headers, "Proxy-Connection");
+	}
+}
+
+void
+evhttp_make_header(struct evhttp_connection *evcon, struct evhttp_request *req)
+{
+	char line[1024];
+	struct evkeyval *header;
+
+	/*
+	 * Depending if this is a HTTP request or response, we might need to
+	 * add some new headers or remove existing headers.
+	 */
+	if (req->kind == EVHTTP_REQUEST) {
+		evhttp_make_header_request(evcon, req);
+	} else {
+		evhttp_make_header_response(evcon, req);
+	}
+
+	TAILQ_FOREACH(header, req->output_headers, next) {
+		evutil_snprintf(line, sizeof(line), "%s: %s\r\n",
+		    header->key, header->value);
+		evbuffer_add(evcon->output_buffer, line, strlen(line));
+	}
+	evbuffer_add(evcon->output_buffer, "\r\n", 2);
+
+	if (EVBUFFER_LENGTH(req->output_buffer) > 0) {
+		/*
+		 * For a request, we add the POST data, for a reply, this
+		 * is the regular data.
+		 */
+		evbuffer_add_buffer(evcon->output_buffer, req->output_buffer);
+	}
+}
+
+/* Separated host, port and file from URI */
+
+int
+evhttp_hostportfile(char *url, char **phost, u_short *pport, char **pfile)
+{
+	/* XXX not threadsafe. */
+	static char host[1024];
+	static char file[1024];
+	char *p;
+	const char *p2;
+	int len;
+	u_short port;
+
+	len = strlen(HTTP_PREFIX);
+	if (strncasecmp(url, HTTP_PREFIX, len))
+		return (-1);
+
+	url += len;
+
+	/* We might overrun */
+	if (strlcpy(host, url, sizeof (host)) >= sizeof(host))
+		return (-1);
+
+	p = strchr(host, '/');
+	if (p != NULL) {
+		*p = '\0';
+		p2 = p + 1;
+	} else
+		p2 = NULL;
+
+	if (pfile != NULL) {
+		/* Generate request file */
+		if (p2 == NULL)
+			p2 = "";
+		evutil_snprintf(file, sizeof(file), "/%s", p2);
+	}
+
+	p = strchr(host, ':');
+	if (p != NULL) {
+		*p = '\0';
+		port = atoi(p + 1);
+
+		if (port == 0)
+			return (-1);
+	} else
+		port = HTTP_DEFAULTPORT;
+
+	if (phost != NULL)
+		*phost = host;
+	if (pport != NULL)
+		*pport = port;
+	if (pfile != NULL)
+		*pfile = file;
+
+	return (0);
+}
+
+static int
+evhttp_connection_incoming_fail(struct evhttp_request *req,
+    enum evhttp_connection_error error)
+{
+	switch (error) {
+	case EVCON_HTTP_TIMEOUT:
+	case EVCON_HTTP_EOF:
+		/* 
+		 * these are cases in which we probably should just
+		 * close the connection and not send a reply.  this
+		 * case may happen when a browser keeps a persistent
+		 * connection open and we timeout on the read.
+		 */
+		return (-1);
+	case EVCON_HTTP_INVALID_HEADER:
+	default:	/* xxx: probably should just error on default */
+		/* the callback looks at the uri to determine errors */
+		if (req->uri) {
+			free(req->uri);
+			req->uri = NULL;
+		}
+
+		/* 
+		 * the callback needs to send a reply, once the reply has
+		 * been send, the connection should get freed.
+		 */
+		(*req->cb)(req, req->cb_arg);
+	}
+	
+	return (0);
+}
+
+void
+evhttp_connection_fail(struct evhttp_connection *evcon,
+    enum evhttp_connection_error error)
+{
+	struct evhttp_request* req = TAILQ_FIRST(&evcon->requests);
+	void (*cb)(struct evhttp_request *, void *);
+	void *cb_arg;
+	assert(req != NULL);
+	
+	if (evcon->flags & EVHTTP_CON_INCOMING) {
+		/* 
+		 * for incoming requests, there are two different
+		 * failure cases.  it's either a network level error
+		 * or an http layer error. for problems on the network
+		 * layer like timeouts we just drop the connections.
+		 * For HTTP problems, we might have to send back a
+		 * reply before the connection can be freed.
+		 */
+		if (evhttp_connection_incoming_fail(req, error) == -1)
+			evhttp_connection_free(evcon);
+		return;
+	}
+
+	/* save the callback for later; the cb might free our object */
+	cb = req->cb;
+	cb_arg = req->cb_arg;
+
+	TAILQ_REMOVE(&evcon->requests, req, next);
+	evhttp_request_free(req);
+
+	/* xxx: maybe we should fail all requests??? */
+
+	/* reset the connection */
+	evhttp_connection_reset(evcon);
+	
+	/* We are trying the next request that was queued on us */
+	if (TAILQ_FIRST(&evcon->requests) != NULL)
+		evhttp_connection_connect(evcon);
+
+	/* inform the user */
+	if (cb != NULL)
+		(*cb)(NULL, cb_arg);
+}
+
+void
+evhttp_write(int fd, short what, void *arg)
+{
+	struct evhttp_connection *evcon = arg;
+	int n;
+
+	if (what == EV_TIMEOUT) {
+		evhttp_connection_fail(evcon, EVCON_HTTP_TIMEOUT);
+		return;
+	}
+
+	n = evbuffer_write(evcon->output_buffer, fd);
+	if (n == -1) {
+		event_debug(("%s: evbuffer_write", __func__));
+		evhttp_connection_fail(evcon, EVCON_HTTP_EOF);
+		return;
+	}
+
+	if (n == 0) {
+		event_debug(("%s: write nothing", __func__));
+		evhttp_connection_fail(evcon, EVCON_HTTP_EOF);
+		return;
+	}
+
+	if (EVBUFFER_LENGTH(evcon->output_buffer) != 0) {
+		evhttp_add_event(&evcon->ev, 
+		    evcon->timeout, HTTP_WRITE_TIMEOUT);
+		return;
+	}
+
+	/* Activate our call back */
+	if (evcon->cb != NULL)
+		(*evcon->cb)(evcon, evcon->cb_arg);
+}
+
+/**
+ * Advance the connection state.
+ * - If this is an outgoing connection, we've just processed the response;
+ *   idle or close the connection.
+ * - If this is an incoming connection, we've just processed the request;
+ *   respond.
+ */
+static void
+evhttp_connection_done(struct evhttp_connection *evcon)
+{
+	struct evhttp_request *req = TAILQ_FIRST(&evcon->requests);
+	int con_outgoing = evcon->flags & EVHTTP_CON_OUTGOING;
+
+	if (con_outgoing) {
+		/* idle or close the connection */
+	        int need_close;
+		TAILQ_REMOVE(&evcon->requests, req, next);
+		req->evcon = NULL;
+
+		evcon->state = EVCON_IDLE;
+
+		need_close = 
+		    evhttp_is_connection_close(req->flags, req->input_headers)||
+		    evhttp_is_connection_close(req->flags, req->output_headers);
+
+		/* check if we got asked to close the connection */
+		if (need_close)
+			evhttp_connection_reset(evcon);
+
+		if (TAILQ_FIRST(&evcon->requests) != NULL) {
+			/*
+			 * We have more requests; reset the connection
+			 * and deal with the next request.
+			 */
+			if (!evhttp_connected(evcon))
+				evhttp_connection_connect(evcon);
+			else
+				evhttp_request_dispatch(evcon);
+		} else if (!need_close) {
+			/*
+			 * The connection is going to be persistent, but we
+			 * need to detect if the other side closes it.
+			 */
+			evhttp_connection_start_detectclose(evcon);
+		}
+	} else {
+		/*
+		 * incoming connection - we need to leave the request on the
+		 * connection so that we can reply to it.
+		 */
+		evcon->state = EVCON_WRITING;
+	}
+
+	/* notify the user of the request */
+	(*req->cb)(req, req->cb_arg);
+
+	/* if this was an outgoing request, we own and it's done. so free it */
+	if (con_outgoing) {
+		evhttp_request_free(req);
+	}
+}
+
+/*
+ * Handles reading from a chunked request.
+ *   return ALL_DATA_READ:
+ *     all data has been read
+ *   return MORE_DATA_EXPECTED:
+ *     more data is expected
+ *   return DATA_CORRUPTED:
+ *     data is corrupted
+ *   return REQUEST_CANCLED:
+ *     request was canceled by the user calling evhttp_cancel_request
+ */
+
+static enum message_read_status
+evhttp_handle_chunked_read(struct evhttp_request *req, struct evbuffer *buf)
+{
+	int len;
+
+	while ((len = EVBUFFER_LENGTH(buf)) > 0) {
+		if (req->ntoread < 0) {
+			/* Read chunk size */
+			ev_int64_t ntoread;
+			char *p = evbuffer_readline(buf);
+			char *endp;
+			int error;
+			if (p == NULL)
+				break;
+			/* the last chunk is on a new line? */
+			if (strlen(p) == 0) {
+				free(p);
+				continue;
+			}
+			ntoread = evutil_strtoll(p, &endp, 16);
+			error = (*p == '\0' ||
+			    (*endp != '\0' && *endp != ' ') ||
+			    ntoread < 0);
+			free(p);
+			if (error) {
+				/* could not get chunk size */
+				return (DATA_CORRUPTED);
+			}
+			req->ntoread = ntoread;
+			if (req->ntoread == 0) {
+				/* Last chunk */
+				return (ALL_DATA_READ);
+			}
+			continue;
+		}
+
+		/* don't have enough to complete a chunk; wait for more */
+		if (len < req->ntoread)
+			return (MORE_DATA_EXPECTED);
+
+		/* Completed chunk */
+		evbuffer_add(req->input_buffer,
+		    EVBUFFER_DATA(buf), req->ntoread);
+		evbuffer_drain(buf, req->ntoread);
+		req->ntoread = -1;
+		if (req->chunk_cb != NULL) {
+			(*req->chunk_cb)(req, req->cb_arg);
+			evbuffer_drain(req->input_buffer,
+			    EVBUFFER_LENGTH(req->input_buffer));
+		}
+	}
+
+	return (MORE_DATA_EXPECTED);
+}
+
+static void
+evhttp_read_trailer(struct evhttp_connection *evcon, struct evhttp_request *req)
+{
+	struct evbuffer *buf = evcon->input_buffer;
+
+	switch (evhttp_parse_headers(req, buf)) {
+	case DATA_CORRUPTED:
+		evhttp_connection_fail(evcon, EVCON_HTTP_INVALID_HEADER);
+		break;
+	case ALL_DATA_READ:
+		event_del(&evcon->ev);
+		evhttp_connection_done(evcon);
+		break;
+	case MORE_DATA_EXPECTED:
+	default:
+		evhttp_add_event(&evcon->ev, evcon->timeout,
+		    HTTP_READ_TIMEOUT);
+		break;
+	}
+}
+
+static void
+evhttp_read_body(struct evhttp_connection *evcon, struct evhttp_request *req)
+{
+	struct evbuffer *buf = evcon->input_buffer;
+	
+	if (req->chunked) {
+		switch (evhttp_handle_chunked_read(req, buf)) {
+		case ALL_DATA_READ:
+			/* finished last chunk */
+			evcon->state = EVCON_READING_TRAILER;
+			evhttp_read_trailer(evcon, req);
+			return;
+		case DATA_CORRUPTED:
+			/* corrupted data */
+			evhttp_connection_fail(evcon,
+			    EVCON_HTTP_INVALID_HEADER);
+			return;
+		case REQUEST_CANCELED:
+			/* request canceled */
+			evhttp_request_free(req);
+			return;
+		case MORE_DATA_EXPECTED:
+		default:
+			break;
+		}
+	} else if (req->ntoread < 0) {
+		/* Read until connection close. */
+		evbuffer_add_buffer(req->input_buffer, buf);
+	} else if (EVBUFFER_LENGTH(buf) >= req->ntoread) {
+		/* Completed content length */
+		evbuffer_add(req->input_buffer, EVBUFFER_DATA(buf),
+		    req->ntoread);
+		evbuffer_drain(buf, req->ntoread);
+		req->ntoread = 0;
+		evhttp_connection_done(evcon);
+		return;
+	}
+	/* Read more! */
+	event_set(&evcon->ev, evcon->fd, EV_READ, evhttp_read, evcon);
+	EVHTTP_BASE_SET(evcon, &evcon->ev);
+	evhttp_add_event(&evcon->ev, evcon->timeout, HTTP_READ_TIMEOUT);
+}
+
+/*
+ * Reads data into a buffer structure until no more data
+ * can be read on the file descriptor or we have read all
+ * the data that we wanted to read.
+ * Execute callback when done.
+ */
+
+void
+evhttp_read(int fd, short what, void *arg)
+{
+	struct evhttp_connection *evcon = arg;
+	struct evhttp_request *req = TAILQ_FIRST(&evcon->requests);
+	struct evbuffer *buf = evcon->input_buffer;
+	int n, len;
+
+	if (what == EV_TIMEOUT) {
+		evhttp_connection_fail(evcon, EVCON_HTTP_TIMEOUT);
+		return;
+	}
+	n = evbuffer_read(buf, fd, -1);
+	len = EVBUFFER_LENGTH(buf);
+	event_debug(("%s: got %d on %d\n", __func__, n, fd));
+	
+	if (n == -1) {
+		if (errno != EINTR && errno != EAGAIN) {
+			event_debug(("%s: evbuffer_read", __func__));
+			evhttp_connection_fail(evcon, EVCON_HTTP_EOF);
+		} else {
+			evhttp_add_event(&evcon->ev, evcon->timeout,
+			    HTTP_READ_TIMEOUT);	       
+		}
+		return;
+	} else if (n == 0) {
+		/* Connection closed */
+		evhttp_connection_done(evcon);
+		return;
+	}
+
+	switch (evcon->state) {
+	case EVCON_READING_FIRSTLINE:
+		evhttp_read_firstline(evcon, req);
+		break;
+	case EVCON_READING_HEADERS:
+		evhttp_read_header(evcon, req);
+		break;
+	case EVCON_READING_BODY:
+		evhttp_read_body(evcon, req);
+		break;
+	case EVCON_READING_TRAILER:
+		evhttp_read_trailer(evcon, req);
+		break;
+	case EVCON_DISCONNECTED:
+	case EVCON_CONNECTING:
+	case EVCON_IDLE:
+	case EVCON_WRITING:
+	default:
+		event_errx(1, "%s: illegal connection state %d",
+			   __func__, evcon->state);
+	}
+}
+
+static void
+evhttp_write_connectioncb(struct evhttp_connection *evcon, void *arg)
+{
+	/* This is after writing the request to the server */
+	struct evhttp_request *req = TAILQ_FIRST(&evcon->requests);
+	assert(req != NULL);
+
+	assert(evcon->state == EVCON_WRITING);
+
+	/* We are done writing our header and are now expecting the response */
+	req->kind = EVHTTP_RESPONSE;
+
+	evhttp_start_read(evcon);
+}
+
+/*
+ * Clean up a connection object
+ */
+
+void
+evhttp_connection_free(struct evhttp_connection *evcon)
+{
+	struct evhttp_request *req;
+
+	/* notify interested parties that this connection is going down */
+	if (evcon->fd != -1) {
+		if (evhttp_connected(evcon) && evcon->closecb != NULL)
+			(*evcon->closecb)(evcon, evcon->closecb_arg);
+	}
+
+	/* remove all requests that might be queued on this connection */
+	while ((req = TAILQ_FIRST(&evcon->requests)) != NULL) {
+		TAILQ_REMOVE(&evcon->requests, req, next);
+		evhttp_request_free(req);
+	}
+
+	if (evcon->http_server != NULL) {
+		struct evhttp *http = evcon->http_server;
+		TAILQ_REMOVE(&http->connections, evcon, next);
+	}
+
+	if (event_initialized(&evcon->close_ev))
+		event_del(&evcon->close_ev);
+
+	if (event_initialized(&evcon->ev))
+		event_del(&evcon->ev);
+	
+	if (evcon->fd != -1)
+		EVUTIL_CLOSESOCKET(evcon->fd);
+
+	if (evcon->bind_address != NULL)
+		free(evcon->bind_address);
+
+	if (evcon->address != NULL)
+		free(evcon->address);
+
+	if (evcon->input_buffer != NULL)
+		evbuffer_free(evcon->input_buffer);
+
+	if (evcon->output_buffer != NULL)
+		evbuffer_free(evcon->output_buffer);
+
+	free(evcon);
+}
+
+void
+evhttp_connection_set_local_address(struct evhttp_connection *evcon,
+    const char *address)
+{
+	assert(evcon->state == EVCON_DISCONNECTED);
+	if (evcon->bind_address)
+		free(evcon->bind_address);
+	if ((evcon->bind_address = strdup(address)) == NULL)
+		event_err(1, "%s: strdup", __func__);
+}
+
+
+static void
+evhttp_request_dispatch(struct evhttp_connection* evcon)
+{
+	struct evhttp_request *req = TAILQ_FIRST(&evcon->requests);
+	
+	/* this should not usually happy but it's possible */
+	if (req == NULL)
+		return;
+
+	/* delete possible close detection events */
+	evhttp_connection_stop_detectclose(evcon);
+	
+	/* we assume that the connection is connected already */
+	assert(evcon->state == EVCON_IDLE);
+
+	evcon->state = EVCON_WRITING;
+
+	/* Create the header from the store arguments */
+	evhttp_make_header(evcon, req);
+
+	evhttp_write_buffer(evcon, evhttp_write_connectioncb, NULL);
+}
+
+/* Reset our connection state */
+void
+evhttp_connection_reset(struct evhttp_connection *evcon)
+{
+	if (event_initialized(&evcon->ev))
+		event_del(&evcon->ev);
+
+	if (evcon->fd != -1) {
+		/* inform interested parties about connection close */
+		if (evhttp_connected(evcon) && evcon->closecb != NULL)
+			(*evcon->closecb)(evcon, evcon->closecb_arg);
+
+		EVUTIL_CLOSESOCKET(evcon->fd);
+		evcon->fd = -1;
+	}
+	evcon->state = EVCON_DISCONNECTED;
+}
+
+static void
+evhttp_detect_close_cb(int fd, short what, void *arg)
+{
+	struct evhttp_connection *evcon = arg;
+	evhttp_connection_reset(evcon);
+}
+
+static void
+evhttp_connection_start_detectclose(struct evhttp_connection *evcon)
+{
+	evcon->flags |= EVHTTP_CON_CLOSEDETECT;
+
+	if (event_initialized(&evcon->close_ev))
+		event_del(&evcon->close_ev);
+	event_set(&evcon->close_ev, evcon->fd, EV_READ,
+	    evhttp_detect_close_cb, evcon);
+	EVHTTP_BASE_SET(evcon, &evcon->close_ev);
+	event_add(&evcon->close_ev, NULL);
+}
+
+static void
+evhttp_connection_stop_detectclose(struct evhttp_connection *evcon)
+{
+	evcon->flags &= ~EVHTTP_CON_CLOSEDETECT;
+	event_del(&evcon->close_ev);
+}
+
+static void
+evhttp_connection_retry(int fd, short what, void *arg)
+{
+	struct evhttp_connection *evcon = arg;
+
+	evcon->state = EVCON_DISCONNECTED;
+	evhttp_connection_connect(evcon);
+}
+
+/*
+ * Call back for asynchronous connection attempt.
+ */
+
+static void
+evhttp_connectioncb(int fd, short what, void *arg)
+{
+	struct evhttp_connection *evcon = arg;
+	int error;
+	socklen_t errsz = sizeof(error);
+		
+	if (what == EV_TIMEOUT) {
+		event_debug(("%s: connection timeout for \"%s:%d\" on %d",
+			__func__, evcon->address, evcon->port, evcon->fd));
+		goto cleanup;
+	}
+
+	/* Check if the connection completed */
+	if (getsockopt(evcon->fd, SOL_SOCKET, SO_ERROR, (void*)&error,
+		       &errsz) == -1) {
+		event_debug(("%s: getsockopt for \"%s:%d\" on %d",
+			__func__, evcon->address, evcon->port, evcon->fd));
+		goto cleanup;
+	}
+
+	if (error) {
+		event_debug(("%s: connect failed for \"%s:%d\" on %d: %s",
+		    __func__, evcon->address, evcon->port, evcon->fd,
+			strerror(error)));
+		goto cleanup;
+	}
+
+	/* We are connected to the server now */
+	event_debug(("%s: connected to \"%s:%d\" on %d\n",
+			__func__, evcon->address, evcon->port, evcon->fd));
+
+	/* Reset the retry count as we were successful in connecting */
+	evcon->retry_cnt = 0;
+	evcon->state = EVCON_IDLE;
+
+	/* try to start requests that have queued up on this connection */
+	evhttp_request_dispatch(evcon);
+	return;
+
+ cleanup:
+	if (evcon->retry_max < 0 || evcon->retry_cnt < evcon->retry_max) {
+		evtimer_set(&evcon->ev, evhttp_connection_retry, evcon);
+		EVHTTP_BASE_SET(evcon, &evcon->ev);
+		evhttp_add_event(&evcon->ev, MIN(3600, 2 << evcon->retry_cnt),
+		    HTTP_CONNECT_TIMEOUT);
+		evcon->retry_cnt++;
+		return;
+	}
+	evhttp_connection_reset(evcon);
+
+	/* for now, we just signal all requests by executing their callbacks */
+	while (TAILQ_FIRST(&evcon->requests) != NULL) {
+		struct evhttp_request *request = TAILQ_FIRST(&evcon->requests);
+		TAILQ_REMOVE(&evcon->requests, request, next);
+		request->evcon = NULL;
+
+		/* we might want to set an error here */
+		request->cb(request, request->cb_arg);
+		evhttp_request_free(request);
+	}
+}
+
+/*
+ * Check if we got a valid response code.
+ */
+
+static int
+evhttp_valid_response_code(int code)
+{
+	if (code == 0)
+		return (0);
+
+	return (1);
+}
+
+/* Parses the status line of a web server */
+
+static int
+evhttp_parse_response_line(struct evhttp_request *req, char *line)
+{
+	char *protocol;
+	char *number;
+	char *readable;
+
+	protocol = strsep(&line, " ");
+	if (line == NULL)
+		return (-1);
+	number = strsep(&line, " ");
+	if (line == NULL)
+		return (-1);
+	readable = line;
+
+	if (strcmp(protocol, "HTTP/1.0") == 0) {
+		req->major = 1;
+		req->minor = 0;
+	} else if (strcmp(protocol, "HTTP/1.1") == 0) {
+		req->major = 1;
+		req->minor = 1;
+	} else {
+		event_debug(("%s: bad protocol \"%s\"",
+			__func__, protocol));
+		return (-1);
+	}
+
+	req->response_code = atoi(number);
+	if (!evhttp_valid_response_code(req->response_code)) {
+		event_debug(("%s: bad response code \"%s\"",
+			__func__, number));
+		return (-1);
+	}
+
+	if ((req->response_code_line = strdup(readable)) == NULL)
+		event_err(1, "%s: strdup", __func__);
+
+	return (0);
+}
+
+/* Parse the first line of a HTTP request */
+
+static int
+evhttp_parse_request_line(struct evhttp_request *req, char *line)
+{
+	char *method;
+	char *uri;
+	char *version;
+
+	/* Parse the request line */
+	method = strsep(&line, " ");
+	if (line == NULL)
+		return (-1);
+	uri = strsep(&line, " ");
+	if (line == NULL)
+		return (-1);
+	version = strsep(&line, " ");
+	if (line != NULL)
+		return (-1);
+
+	/* First line */
+	if (strcmp(method, "GET") == 0) {
+		req->type = EVHTTP_REQ_GET;
+	} else if (strcmp(method, "POST") == 0) {
+		req->type = EVHTTP_REQ_POST;
+	} else if (strcmp(method, "HEAD") == 0) {
+		req->type = EVHTTP_REQ_HEAD;
+	} else {
+		event_debug(("%s: bad method %s on request %p from %s",
+			__func__, method, req, req->remote_host));
+		return (-1);
+	}
+
+	if (strcmp(version, "HTTP/1.0") == 0) {
+		req->major = 1;
+		req->minor = 0;
+	} else if (strcmp(version, "HTTP/1.1") == 0) {
+		req->major = 1;
+		req->minor = 1;
+	} else {
+		event_debug(("%s: bad version %s on request %p from %s",
+			__func__, version, req, req->remote_host));
+		return (-1);
+	}
+
+	if ((req->uri = strdup(uri)) == NULL) {
+		event_debug(("%s: evhttp_decode_uri", __func__));
+		return (-1);
+	}
+
+	/* determine if it's a proxy request */
+	if (strlen(req->uri) > 0 && req->uri[0] != '/')
+		req->flags |= EVHTTP_PROXY_REQUEST;
+
+	return (0);
+}
+
+const char *
+evhttp_find_header(const struct evkeyvalq *headers, const char *key)
+{
+	struct evkeyval *header;
+
+	TAILQ_FOREACH(header, headers, next) {
+		if (strcasecmp(header->key, key) == 0)
+			return (header->value);
+	}
+
+	return (NULL);
+}
+
+void
+evhttp_clear_headers(struct evkeyvalq *headers)
+{
+	struct evkeyval *header;
+
+	for (header = TAILQ_FIRST(headers);
+	    header != NULL;
+	    header = TAILQ_FIRST(headers)) {
+		TAILQ_REMOVE(headers, header, next);
+		free(header->key);
+		free(header->value);
+		free(header);
+	}
+}
+
+/*
+ * Returns 0,  if the header was successfully removed.
+ * Returns -1, if the header could not be found.
+ */
+
+int
+evhttp_remove_header(struct evkeyvalq *headers, const char *key)
+{
+	struct evkeyval *header;
+
+	TAILQ_FOREACH(header, headers, next) {
+		if (strcasecmp(header->key, key) == 0)
+			break;
+	}
+
+	if (header == NULL)
+		return (-1);
+
+	/* Free and remove the header that we found */
+	TAILQ_REMOVE(headers, header, next);
+	free(header->key);
+	free(header->value);
+	free(header);
+
+	return (0);
+}
+
+int
+evhttp_add_header(struct evkeyvalq *headers,
+    const char *key, const char *value)
+{
+	struct evkeyval *header = NULL;
+
+	event_debug(("%s: key: %s val: %s\n", __func__, key, value));
+
+	if (strchr(value, '\r') != NULL || strchr(value, '\n') != NULL ||
+	    strchr(key, '\r') != NULL || strchr(key, '\n') != NULL) {
+		/* drop illegal headers */
+		event_debug(("%s: dropping illegal header\n", __func__));
+		return (-1);
+	}
+
+	header = calloc(1, sizeof(struct evkeyval));
+	if (header == NULL) {
+		event_warn("%s: calloc", __func__);
+		return (-1);
+	}
+	if ((header->key = strdup(key)) == NULL) {
+		free(header);
+		event_warn("%s: strdup", __func__);
+		return (-1);
+	}
+	if ((header->value = strdup(value)) == NULL) {
+		free(header->key);
+		free(header);
+		event_warn("%s: strdup", __func__);
+		return (-1);
+	}
+
+	TAILQ_INSERT_TAIL(headers, header, next);
+
+	return (0);
+}
+
+/*
+ * Parses header lines from a request or a response into the specified
+ * request object given an event buffer.
+ *
+ * Returns
+ *   DATA_CORRUPTED      on error
+ *   MORE_DATA_EXPECTED  when we need to read more headers
+ *   ALL_DATA_READ       when all headers have been read.
+ */
+
+enum message_read_status
+evhttp_parse_firstline(struct evhttp_request *req, struct evbuffer *buffer)
+{
+	char *line;
+	enum message_read_status status = ALL_DATA_READ;
+
+	line = evbuffer_readline(buffer);
+	if (line == NULL)
+		return (MORE_DATA_EXPECTED);
+
+	switch (req->kind) {
+	case EVHTTP_REQUEST:
+		if (evhttp_parse_request_line(req, line) == -1)
+			status = DATA_CORRUPTED;
+		break;
+	case EVHTTP_RESPONSE:
+		if (evhttp_parse_response_line(req, line) == -1)
+			status = DATA_CORRUPTED;
+		break;
+	default:
+		status = DATA_CORRUPTED;
+	}
+
+	free(line);
+	return (status);
+}
+
+static int
+evhttp_append_to_last_header(struct evkeyvalq *headers, const char *line)
+{
+	struct evkeyval *header = TAILQ_LAST(headers, evkeyvalq);
+	char *newval;
+	size_t old_len, line_len;
+
+	if (header == NULL)
+		return (-1);
+
+	old_len = strlen(header->value);
+	line_len = strlen(line);
+
+	newval = realloc(header->value, old_len + line_len + 1);
+	if (newval == NULL)
+		return (-1);
+
+	memcpy(newval + old_len, line, line_len + 1);
+	header->value = newval;
+
+	return (0);
+}
+
+enum message_read_status
+evhttp_parse_headers(struct evhttp_request *req, struct evbuffer* buffer)
+{
+	char *line;
+	enum message_read_status status = MORE_DATA_EXPECTED;
+
+	struct evkeyvalq* headers = req->input_headers;
+	while ((line = evbuffer_readline(buffer))
+	       != NULL) {
+		char *skey, *svalue;
+
+		if (*line == '\0') { /* Last header - Done */
+			status = ALL_DATA_READ;
+			free(line);
+			break;
+		}
+
+		/* Check if this is a continuation line */
+		if (*line == ' ' || *line == '\t') {
+			if (evhttp_append_to_last_header(headers, line) == -1)
+				goto error;
+			continue;
+		}
+
+		/* Processing of header lines */
+		svalue = line;
+		skey = strsep(&svalue, ":");
+		if (svalue == NULL)
+			goto error;
+
+		svalue += strspn(svalue, " ");
+
+		if (evhttp_add_header(headers, skey, svalue) == -1)
+			goto error;
+
+		free(line);
+	}
+
+	return (status);
+
+ error:
+	free(line);
+	return (DATA_CORRUPTED);
+}
+
+static int
+evhttp_get_body_length(struct evhttp_request *req)
+{
+	struct evkeyvalq *headers = req->input_headers;
+	const char *content_length;
+	const char *connection;
+
+	content_length = evhttp_find_header(headers, "Content-Length");
+	connection = evhttp_find_header(headers, "Connection");
+		
+	if (content_length == NULL && connection == NULL)
+		req->ntoread = -1;
+	else if (content_length == NULL &&
+	    strcasecmp(connection, "Close") != 0) {
+		/* Bad combination, we don't know when it will end */
+		event_warnx("%s: we got no content length, but the "
+		    "server wants to keep the connection open: %s.",
+		    __func__, connection);
+		return (-1);
+	} else if (content_length == NULL) {
+		req->ntoread = -1;
+	} else {
+		char *endp;
+		ev_int64_t ntoread = evutil_strtoll(content_length, &endp, 10);
+		if (*content_length == '\0' || *endp != '\0' || ntoread < 0) {
+			event_debug(("%s: illegal content length: %s",
+				__func__, content_length));
+			return (-1);
+		}
+		req->ntoread = ntoread;
+	}
+		
+	event_debug(("%s: bytes to read: %lld (in buffer %ld)\n",
+		__func__, req->ntoread,
+		EVBUFFER_LENGTH(req->evcon->input_buffer)));
+
+	return (0);
+}
+
+static void
+evhttp_get_body(struct evhttp_connection *evcon, struct evhttp_request *req)
+{
+	const char *xfer_enc;
+	
+	/* If this is a request without a body, then we are done */
+	if (req->kind == EVHTTP_REQUEST && req->type != EVHTTP_REQ_POST) {
+		evhttp_connection_done(evcon);
+		return;
+	}
+	evcon->state = EVCON_READING_BODY;
+	xfer_enc = evhttp_find_header(req->input_headers, "Transfer-Encoding");
+	if (xfer_enc != NULL && strcasecmp(xfer_enc, "chunked") == 0) {
+		req->chunked = 1;
+		req->ntoread = -1;
+	} else {
+		if (evhttp_get_body_length(req) == -1) {
+			evhttp_connection_fail(evcon,
+			    EVCON_HTTP_INVALID_HEADER);
+			return;
+		}
+	}
+	evhttp_read_body(evcon, req);
+}
+
+static void
+evhttp_read_firstline(struct evhttp_connection *evcon,
+		      struct evhttp_request *req)
+{
+	enum message_read_status res;
+
+	res = evhttp_parse_firstline(req, evcon->input_buffer);
+	if (res == DATA_CORRUPTED) {
+		/* Error while reading, terminate */
+		event_debug(("%s: bad header lines on %d\n",
+			__func__, evcon->fd));
+		evhttp_connection_fail(evcon, EVCON_HTTP_INVALID_HEADER);
+		return;
+	} else if (res == MORE_DATA_EXPECTED) {
+		/* Need more header lines */
+		evhttp_add_event(&evcon->ev, 
+                    evcon->timeout, HTTP_READ_TIMEOUT);
+		return;
+	}
+
+	evcon->state = EVCON_READING_HEADERS;
+	evhttp_read_header(evcon, req);
+}
+
+static void
+evhttp_read_header(struct evhttp_connection *evcon, struct evhttp_request *req)
+{
+	enum message_read_status res;
+	int fd = evcon->fd;
+
+	res = evhttp_parse_headers(req, evcon->input_buffer);
+	if (res == DATA_CORRUPTED) {
+		/* Error while reading, terminate */
+		event_debug(("%s: bad header lines on %d\n", __func__, fd));
+		evhttp_connection_fail(evcon, EVCON_HTTP_INVALID_HEADER);
+		return;
+	} else if (res == MORE_DATA_EXPECTED) {
+		/* Need more header lines */
+		evhttp_add_event(&evcon->ev, 
+		    evcon->timeout, HTTP_READ_TIMEOUT);
+		return;
+	}
+
+	/* Done reading headers, do the real work */
+	switch (req->kind) {
+	case EVHTTP_REQUEST:
+		event_debug(("%s: checking for post data on %d\n",
+				__func__, fd));
+		evhttp_get_body(evcon, req);
+		break;
+
+	case EVHTTP_RESPONSE:
+		if (req->response_code == HTTP_NOCONTENT ||
+		    req->response_code == HTTP_NOTMODIFIED ||
+		    (req->response_code >= 100 && req->response_code < 200)) {
+			event_debug(("%s: skipping body for code %d\n",
+					__func__, req->response_code));
+			evhttp_connection_done(evcon);
+		} else {
+			event_debug(("%s: start of read body for %s on %d\n",
+				__func__, req->remote_host, fd));
+			evhttp_get_body(evcon, req);
+		}
+		break;
+
+	default:
+		event_warnx("%s: bad header on %d", __func__, fd);
+		evhttp_connection_fail(evcon, EVCON_HTTP_INVALID_HEADER);
+		break;
+	}
+}
+
+/*
+ * Creates a TCP connection to the specified port and executes a callback
+ * when finished.  Failure or sucess is indicate by the passed connection
+ * object.
+ *
+ * Although this interface accepts a hostname, it is intended to take
+ * only numeric hostnames so that non-blocking DNS resolution can
+ * happen elsewhere.
+ */
+
+struct evhttp_connection *
+evhttp_connection_new(const char *address, unsigned short port)
+{
+	struct evhttp_connection *evcon = NULL;
+	
+	event_debug(("Attempting connection to %s:%d\n", address, port));
+
+	if ((evcon = calloc(1, sizeof(struct evhttp_connection))) == NULL) {
+		event_warn("%s: calloc failed", __func__);
+		goto error;
+	}
+
+	evcon->fd = -1;
+	evcon->port = port;
+
+	evcon->timeout = -1;
+	evcon->retry_cnt = evcon->retry_max = 0;
+
+	if ((evcon->address = strdup(address)) == NULL) {
+		event_warn("%s: strdup failed", __func__);
+		goto error;
+	}
+
+	if ((evcon->input_buffer = evbuffer_new()) == NULL) {
+		event_warn("%s: evbuffer_new failed", __func__);
+		goto error;
+	}
+
+	if ((evcon->output_buffer = evbuffer_new()) == NULL) {
+		event_warn("%s: evbuffer_new failed", __func__);
+		goto error;
+	}
+	
+	evcon->state = EVCON_DISCONNECTED;
+	TAILQ_INIT(&evcon->requests);
+
+	return (evcon);
+	
+ error:
+	if (evcon != NULL)
+		evhttp_connection_free(evcon);
+	return (NULL);
+}
+
+void evhttp_connection_set_base(struct evhttp_connection *evcon,
+    struct event_base *base)
+{
+	assert(evcon->base == NULL);
+	assert(evcon->state == EVCON_DISCONNECTED);
+	evcon->base = base;
+}
+
+void
+evhttp_connection_set_timeout(struct evhttp_connection *evcon,
+    int timeout_in_secs)
+{
+	evcon->timeout = timeout_in_secs;
+}
+
+void
+evhttp_connection_set_retries(struct evhttp_connection *evcon,
+    int retry_max)
+{
+	evcon->retry_max = retry_max;
+}
+
+void
+evhttp_connection_set_closecb(struct evhttp_connection *evcon,
+    void (*cb)(struct evhttp_connection *, void *), void *cbarg)
+{
+	evcon->closecb = cb;
+	evcon->closecb_arg = cbarg;
+}
+
+void
+evhttp_connection_get_peer(struct evhttp_connection *evcon,
+    char **address, u_short *port)
+{
+	*address = evcon->address;
+	*port = evcon->port;
+}
+
+int
+evhttp_connection_connect(struct evhttp_connection *evcon)
+{
+	if (evcon->state == EVCON_CONNECTING)
+		return (0);
+	
+	evhttp_connection_reset(evcon);
+
+	assert(!(evcon->flags & EVHTTP_CON_INCOMING));
+	evcon->flags |= EVHTTP_CON_OUTGOING;
+	
+	evcon->fd = bind_socket(evcon->bind_address, 0 /*port*/, 0 /*reuse*/);
+	if (evcon->fd == -1) {
+		event_debug(("%s: failed to bind to \"%s\"",
+			__func__, evcon->bind_address));
+		return (-1);
+	}
+
+	if (socket_connect(evcon->fd, evcon->address, evcon->port) == -1) {
+		EVUTIL_CLOSESOCKET(evcon->fd); evcon->fd = -1;
+		return (-1);
+	}
+
+	/* Set up a callback for successful connection setup */
+	event_set(&evcon->ev, evcon->fd, EV_WRITE, evhttp_connectioncb, evcon);
+	EVHTTP_BASE_SET(evcon, &evcon->ev);
+	evhttp_add_event(&evcon->ev, evcon->timeout, HTTP_CONNECT_TIMEOUT);
+
+	evcon->state = EVCON_CONNECTING;
+	
+	return (0);
+}
+
+/*
+ * Starts an HTTP request on the provided evhttp_connection object.
+ * If the connection object is not connected to the web server already,
+ * this will start the connection.
+ */
+
+int
+evhttp_make_request(struct evhttp_connection *evcon,
+    struct evhttp_request *req,
+    enum evhttp_cmd_type type, const char *uri)
+{
+	/* We are making a request */
+	req->kind = EVHTTP_REQUEST;
+	req->type = type;
+	if (req->uri != NULL)
+		free(req->uri);
+	if ((req->uri = strdup(uri)) == NULL)
+		event_err(1, "%s: strdup", __func__);
+
+	/* Set the protocol version if it is not supplied */
+	if (!req->major && !req->minor) {
+		req->major = 1;
+		req->minor = 1;
+	}
+	
+	assert(req->evcon == NULL);
+	req->evcon = evcon;
+	assert(!(req->flags & EVHTTP_REQ_OWN_CONNECTION));
+	
+	TAILQ_INSERT_TAIL(&evcon->requests, req, next);
+
+	/* If the connection object is not connected; make it so */
+	if (!evhttp_connected(evcon))
+		return (evhttp_connection_connect(evcon));
+
+	/*
+	 * If it's connected already and we are the first in the queue,
+	 * then we can dispatch this request immediately.  Otherwise, it
+	 * will be dispatched once the pending requests are completed.
+	 */
+	if (TAILQ_FIRST(&evcon->requests) == req)
+		evhttp_request_dispatch(evcon);
+
+	return (0);
+}
+
+/*
+ * Reads data from file descriptor into request structure
+ * Request structure needs to be set up correctly.
+ */
+
+void
+evhttp_start_read(struct evhttp_connection *evcon)
+{
+	/* Set up an event to read the headers */
+	if (event_initialized(&evcon->ev))
+		event_del(&evcon->ev);
+	event_set(&evcon->ev, evcon->fd, EV_READ, evhttp_read, evcon);
+	EVHTTP_BASE_SET(evcon, &evcon->ev);
+	
+	evhttp_add_event(&evcon->ev, evcon->timeout, HTTP_READ_TIMEOUT);
+	evcon->state = EVCON_READING_FIRSTLINE;
+}
+
+static void
+evhttp_send_done(struct evhttp_connection *evcon, void *arg)
+{
+	int need_close;
+	struct evhttp_request *req = TAILQ_FIRST(&evcon->requests);
+	TAILQ_REMOVE(&evcon->requests, req, next);
+
+	/* delete possible close detection events */
+	evhttp_connection_stop_detectclose(evcon);
+	
+	need_close =
+	    (req->minor == 0 &&
+		!evhttp_is_connection_keepalive(req->input_headers))||
+	    evhttp_is_connection_close(req->flags, req->input_headers) ||
+	    evhttp_is_connection_close(req->flags, req->output_headers);
+
+	assert(req->flags & EVHTTP_REQ_OWN_CONNECTION);
+	evhttp_request_free(req);
+
+	if (need_close) {
+		evhttp_connection_free(evcon);
+		return;
+	} 
+
+	/* we have a persistent connection; try to accept another request. */
+	if (evhttp_associate_new_request_with_connection(evcon) == -1)
+		evhttp_connection_free(evcon);
+}
+
+/*
+ * Returns an error page.
+ */
+
+void
+evhttp_send_error(struct evhttp_request *req, int error, const char *reason)
+{
+#define ERR_FORMAT "<HTML><HEAD>\n" \
+	    "<TITLE>%d %s</TITLE>\n" \
+	    "</HEAD><BODY>\n" \
+	    "<H1>Method Not Implemented</H1>\n" \
+	    "Invalid method in request<P>\n" \
+	    "</BODY></HTML>\n"
+
+	struct evbuffer *buf = evbuffer_new();
+
+	/* close the connection on error */
+	evhttp_add_header(req->output_headers, "Connection", "close");
+
+	evhttp_response_code(req, error, reason);
+
+	evbuffer_add_printf(buf, ERR_FORMAT, error, reason);
+
+	evhttp_send_page(req, buf);
+
+	evbuffer_free(buf);
+#undef ERR_FORMAT
+}
+
+/* Requires that headers and response code are already set up */
+
+static inline void
+evhttp_send(struct evhttp_request *req, struct evbuffer *databuf)
+{
+	struct evhttp_connection *evcon = req->evcon;
+
+	assert(TAILQ_FIRST(&evcon->requests) == req);
+
+	/* xxx: not sure if we really should expose the data buffer this way */
+	if (databuf != NULL)
+		evbuffer_add_buffer(req->output_buffer, databuf);
+	
+	/* Adds headers to the response */
+	evhttp_make_header(evcon, req);
+
+	evhttp_write_buffer(evcon, evhttp_send_done, NULL);
+}
+
+void
+evhttp_send_reply(struct evhttp_request *req, int code, const char *reason,
+    struct evbuffer *databuf)
+{
+	/* set up to watch for client close */
+	evhttp_connection_start_detectclose(req->evcon);
+	evhttp_response_code(req, code, reason);
+	
+	evhttp_send(req, databuf);
+}
+
+void
+evhttp_send_reply_start(struct evhttp_request *req, int code,
+    const char *reason)
+{
+	/* set up to watch for client close */
+	evhttp_connection_start_detectclose(req->evcon);
+	evhttp_response_code(req, code, reason);
+	if (req->major == 1 && req->minor == 1) {
+		/* use chunked encoding for HTTP/1.1 */
+		evhttp_add_header(req->output_headers, "Transfer-Encoding",
+		    "chunked");
+		req->chunked = 1;
+	}
+	evhttp_make_header(req->evcon, req);
+	evhttp_write_buffer(req->evcon, NULL, NULL);
+}
+
+void
+evhttp_send_reply_chunk(struct evhttp_request *req, struct evbuffer *databuf)
+{
+	if (req->chunked) {
+		evbuffer_add_printf(req->evcon->output_buffer, "%x\r\n",
+				    (unsigned)EVBUFFER_LENGTH(databuf));
+	}
+	evbuffer_add_buffer(req->evcon->output_buffer, databuf);
+	if (req->chunked) {
+		evbuffer_add(req->evcon->output_buffer, "\r\n", 2);
+	}
+	evhttp_write_buffer(req->evcon, NULL, NULL);
+}
+
+void
+evhttp_send_reply_end(struct evhttp_request *req)
+{
+	struct evhttp_connection *evcon = req->evcon;
+
+	if (req->chunked) {
+		evbuffer_add(req->evcon->output_buffer, "0\r\n\r\n", 5);
+		evhttp_write_buffer(req->evcon, evhttp_send_done, NULL);
+		req->chunked = 0;
+	} else if (!event_pending(&evcon->ev, EV_WRITE|EV_TIMEOUT, NULL)) {
+		/* let the connection know that we are done with the request */
+		evhttp_send_done(evcon, NULL);
+	} else {
+		/* make the callback execute after all data has been written */
+		evcon->cb = evhttp_send_done;
+		evcon->cb_arg = NULL;
+	}
+}
+
+void
+evhttp_response_code(struct evhttp_request *req, int code, const char *reason)
+{
+	req->kind = EVHTTP_RESPONSE;
+	req->response_code = code;
+	if (req->response_code_line != NULL)
+		free(req->response_code_line);
+	req->response_code_line = strdup(reason);
+}
+
+void
+evhttp_send_page(struct evhttp_request *req, struct evbuffer *databuf)
+{
+	if (!req->major || !req->minor) {
+		req->major = 1;
+		req->minor = 1;
+	}
+	
+	if (req->kind != EVHTTP_RESPONSE)
+		evhttp_response_code(req, 200, "OK");
+
+	evhttp_clear_headers(req->output_headers);
+	evhttp_add_header(req->output_headers, "Content-Type", "text/html");
+	evhttp_add_header(req->output_headers, "Connection", "close");
+
+	evhttp_send(req, databuf);
+}
+
+static const char uri_chars[256] = {
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 1, 0, 0, 1, 0, 0, 1,   1, 1, 1, 1, 1, 1, 1, 1,
+	1, 1, 1, 1, 1, 1, 1, 1,   1, 1, 1, 0, 0, 1, 0, 0,
+	/* 64 */
+	1, 1, 1, 1, 1, 1, 1, 1,   1, 1, 1, 1, 1, 1, 1, 1,
+	1, 1, 1, 1, 1, 1, 1, 1,   1, 1, 1, 0, 0, 0, 0, 1,
+	0, 1, 1, 1, 1, 1, 1, 1,   1, 1, 1, 1, 1, 1, 1, 1,
+	1, 1, 1, 1, 1, 1, 1, 1,   1, 1, 1, 0, 0, 0, 1, 0,
+	/* 128 */
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	/* 192 */
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+	0, 0, 0, 0, 0, 0, 0, 0,   0, 0, 0, 0, 0, 0, 0, 0,
+};
+
+/*
+ * Helper functions to encode/decode a URI.
+ * The returned string must be freed by the caller.
+ */
+char *
+evhttp_encode_uri(const char *uri)
+{
+	struct evbuffer *buf = evbuffer_new();
+	char *p;
+
+	for (p = (char *)uri; *p != '\0'; p++) {
+		if (uri_chars[(u_char)(*p)]) {
+			evbuffer_add(buf, p, 1);
+		} else {
+			evbuffer_add_printf(buf, "%%%02X", (u_char)(*p));
+		}
+	}
+	evbuffer_add(buf, "", 1);
+	p = strdup((char *)EVBUFFER_DATA(buf));
+	evbuffer_free(buf);
+	
+	return (p);
+}
+
+char *
+evhttp_decode_uri(const char *uri)
+{
+	char c, *ret;
+	int i, j, in_query = 0;
+	
+	ret = malloc(strlen(uri) + 1);
+	if (ret == NULL)
+		event_err(1, "%s: malloc(%lu)", __func__,
+			  (unsigned long)(strlen(uri) + 1));
+	
+	for (i = j = 0; uri[i] != '\0'; i++) {
+		c = uri[i];
+		if (c == '?') {
+			in_query = 1;
+		} else if (c == '+' && in_query) {
+			c = ' ';
+		} else if (c == '%' && isxdigit((unsigned char)uri[i+1]) &&
+		    isxdigit((unsigned char)uri[i+2])) {
+			char tmp[] = { uri[i+1], uri[i+2], '\0' };
+			c = (char)strtol(tmp, NULL, 16);
+			i += 2;
+		}
+		ret[j++] = c;
+	}
+	ret[j] = '\0';
+	
+	return (ret);
+}
+
+/* 
+ * Helper function to parse out arguments in a query.
+ * The arguments are separated by key and value.
+ * URI should already be decoded.
+ */
+
+void
+evhttp_parse_query(const char *uri, struct evkeyvalq *headers)
+{
+	char *line;
+	char *argument;
+	char *p;
+
+	TAILQ_INIT(headers);
+
+	/* No arguments - we are done */
+	if (strchr(uri, '?') == NULL)
+		return;
+
+	if ((line = strdup(uri)) == NULL)
+		event_err(1, "%s: strdup", __func__);
+
+
+	argument = line;
+
+	/* We already know that there has to be a ? */
+	strsep(&argument, "?");
+
+	p = argument;
+	while (p != NULL && *p != '\0') {
+		char *key, *value;
+		argument = strsep(&p, "&");
+
+		value = argument;
+		key = strsep(&value, "=");
+		if (value == NULL)
+			goto error;
+
+		value = evhttp_decode_uri(value);
+		event_debug(("Query Param: %s -> %s\n", key, value));
+		evhttp_add_header(headers, key, value);
+		free(value);
+	}
+
+ error:
+	free(line);
+}
+
+static struct evhttp_cb *
+evhttp_dispatch_callback(struct httpcbq *callbacks, struct evhttp_request *req)
+{
+	struct evhttp_cb *cb;
+	size_t offset = 0;
+
+	/* Test for different URLs */
+	char *p = strchr(req->uri, '?');
+	if (p != NULL)
+		offset = (size_t)(p - req->uri);
+
+	TAILQ_FOREACH(cb, callbacks, next) {
+		int res = 0;
+		if (p == NULL) {
+			res = strcmp(cb->what, req->uri) == 0;
+		} else {
+			res = ((strncmp(cb->what, req->uri, offset) == 0) &&
+					(cb->what[offset] == '\0'));
+		}
+
+		if (res)
+			return (cb);
+	}
+
+	return (NULL);
+}
+
+static void
+evhttp_handle_request(struct evhttp_request *req, void *arg)
+{
+	struct evhttp *http = arg;
+	struct evhttp_cb *cb = NULL;
+
+	if (req->uri == NULL) {
+		evhttp_send_error(req, HTTP_BADREQUEST, "Bad Request");
+		return;
+	}
+
+	if ((cb = evhttp_dispatch_callback(&http->callbacks, req)) != NULL) {
+		(*cb->cb)(req, cb->cbarg);
+		return;
+	}
+
+	/* Generic call back */
+	if (http->gencb) {
+		(*http->gencb)(req, http->gencbarg);
+		return;
+	} else {
+		/* We need to send a 404 here */
+#define ERR_FORMAT "<html><head>" \
+		    "<title>404 Not Found</title>" \
+		    "</head><body>" \
+		    "<h1>Not Found</h1>" \
+		    "<p>The requested URL %s was not found on this server.</p>"\
+		    "</body></html>\n"
+
+		char *escaped_html = evhttp_htmlescape(req->uri);
+		struct evbuffer *buf = evbuffer_new();
+
+		evhttp_response_code(req, HTTP_NOTFOUND, "Not Found");
+
+		evbuffer_add_printf(buf, ERR_FORMAT, escaped_html);
+
+		free(escaped_html);
+
+		evhttp_send_page(req, buf);
+
+		evbuffer_free(buf);
+#undef ERR_FORMAT
+	}
+}
+
+static void
+accept_socket(int fd, short what, void *arg)
+{
+	struct evhttp *http = arg;
+	struct sockaddr_storage ss;
+	socklen_t addrlen = sizeof(ss);
+	int nfd;
+
+	if ((nfd = accept(fd, (struct sockaddr *)&ss, &addrlen)) == -1) {
+		if (errno != EAGAIN && errno != EINTR)
+			event_warn("%s: bad accept", __func__);
+		return;
+	}
+	if (evutil_make_socket_nonblocking(nfd) < 0)
+		return;
+
+	evhttp_get_request(http, nfd, (struct sockaddr *)&ss, addrlen);
+}
+
+int
+evhttp_bind_socket(struct evhttp *http, const char *address, u_short port)
+{
+	int fd;
+	int res;
+
+	if ((fd = bind_socket(address, port, 1 /*reuse*/)) == -1)
+		return (-1);
+
+	if (listen(fd, 128) == -1) {
+		event_warn("%s: listen", __func__);
+		EVUTIL_CLOSESOCKET(fd);
+		return (-1);
+	}
+
+	res = evhttp_accept_socket(http, fd);
+	
+	if (res != -1)
+		event_debug(("Bound to port %d - Awaiting connections ... ",
+			port));
+
+	return (res);
+}
+
+int
+evhttp_accept_socket(struct evhttp *http, int fd)
+{
+	struct evhttp_bound_socket *bound;
+	struct event *ev;
+	int res;
+
+	bound = malloc(sizeof(struct evhttp_bound_socket));
+	if (bound == NULL)
+		return (-1);
+
+	ev = &bound->bind_ev;
+
+	/* Schedule the socket for accepting */
+	event_set(ev, fd, EV_READ | EV_PERSIST, accept_socket, http);
+	EVHTTP_BASE_SET(http, ev);
+
+	res = event_add(ev, NULL);
+
+	if (res == -1) {
+		free(bound);
+		return (-1);
+	}
+
+	TAILQ_INSERT_TAIL(&http->sockets, bound, next);
+
+	return (0);
+}
+
+static struct evhttp*
+evhttp_new_object(void)
+{
+	struct evhttp *http = NULL;
+
+	if ((http = calloc(1, sizeof(struct evhttp))) == NULL) {
+		event_warn("%s: calloc", __func__);
+		return (NULL);
+	}
+
+	http->timeout = -1;
+
+	TAILQ_INIT(&http->sockets);
+	TAILQ_INIT(&http->callbacks);
+	TAILQ_INIT(&http->connections);
+
+	return (http);
+}
+
+struct evhttp *
+evhttp_new(struct event_base *base)
+{
+	struct evhttp *http = evhttp_new_object();
+
+	http->base = base;
+
+	return (http);
+}
+
+/*
+ * Start a web server on the specified address and port.
+ */
+
+struct evhttp *
+evhttp_start(const char *address, u_short port)
+{
+	struct evhttp *http = evhttp_new_object();
+
+	if (evhttp_bind_socket(http, address, port) == -1) {
+		free(http);
+		return (NULL);
+	}
+
+	return (http);
+}
+
+void
+evhttp_free(struct evhttp* http)
+{
+	struct evhttp_cb *http_cb;
+	struct evhttp_connection *evcon;
+	struct evhttp_bound_socket *bound;
+	int fd;
+
+	/* Remove the accepting part */
+	while ((bound = TAILQ_FIRST(&http->sockets)) != NULL) {
+		TAILQ_REMOVE(&http->sockets, bound, next);
+
+		fd = bound->bind_ev.ev_fd;
+		event_del(&bound->bind_ev);
+		EVUTIL_CLOSESOCKET(fd);
+
+		free(bound);
+	}
+
+	while ((evcon = TAILQ_FIRST(&http->connections)) != NULL) {
+		/* evhttp_connection_free removes the connection */
+		evhttp_connection_free(evcon);
+	}
+
+	while ((http_cb = TAILQ_FIRST(&http->callbacks)) != NULL) {
+		TAILQ_REMOVE(&http->callbacks, http_cb, next);
+		free(http_cb->what);
+		free(http_cb);
+	}
+	
+	free(http);
+}
+
+void
+evhttp_set_timeout(struct evhttp* http, int timeout_in_secs)
+{
+	http->timeout = timeout_in_secs;
+}
+
+void
+evhttp_set_cb(struct evhttp *http, const char *uri,
+    void (*cb)(struct evhttp_request *, void *), void *cbarg)
+{
+	struct evhttp_cb *http_cb;
+
+	if ((http_cb = calloc(1, sizeof(struct evhttp_cb))) == NULL)
+		event_err(1, "%s: calloc", __func__);
+
+	http_cb->what = strdup(uri);
+	http_cb->cb = cb;
+	http_cb->cbarg = cbarg;
+
+	TAILQ_INSERT_TAIL(&http->callbacks, http_cb, next);
+}
+
+int
+evhttp_del_cb(struct evhttp *http, const char *uri)
+{
+	struct evhttp_cb *http_cb;
+
+	TAILQ_FOREACH(http_cb, &http->callbacks, next) {
+		if (strcmp(http_cb->what, uri) == 0)
+			break;
+	}
+	if (http_cb == NULL)
+		return (-1);
+
+	TAILQ_REMOVE(&http->callbacks, http_cb, next);
+	free(http_cb->what);
+	free(http_cb);
+
+	return (0);
+}
+
+void
+evhttp_set_gencb(struct evhttp *http,
+    void (*cb)(struct evhttp_request *, void *), void *cbarg)
+{
+	http->gencb = cb;
+	http->gencbarg = cbarg;
+}
+
+/*
+ * Request related functions
+ */
+
+struct evhttp_request *
+evhttp_request_new(void (*cb)(struct evhttp_request *, void *), void *arg)
+{
+	struct evhttp_request *req = NULL;
+
+	/* Allocate request structure */
+	if ((req = calloc(1, sizeof(struct evhttp_request))) == NULL) {
+		event_warn("%s: calloc", __func__);
+		goto error;
+	}
+
+	req->kind = EVHTTP_RESPONSE;
+	req->input_headers = calloc(1, sizeof(struct evkeyvalq));
+	if (req->input_headers == NULL) {
+		event_warn("%s: calloc", __func__);
+		goto error;
+	}
+	TAILQ_INIT(req->input_headers);
+
+	req->output_headers = calloc(1, sizeof(struct evkeyvalq));
+	if (req->output_headers == NULL) {
+		event_warn("%s: calloc", __func__);
+		goto error;
+	}
+	TAILQ_INIT(req->output_headers);
+
+	if ((req->input_buffer = evbuffer_new()) == NULL) {
+		event_warn("%s: evbuffer_new", __func__);
+		goto error;
+	}
+
+	if ((req->output_buffer = evbuffer_new()) == NULL) {
+		event_warn("%s: evbuffer_new", __func__);
+		goto error;
+	}
+
+	req->cb = cb;
+	req->cb_arg = arg;
+
+	return (req);
+
+ error:
+	if (req != NULL)
+		evhttp_request_free(req);
+	return (NULL);
+}
+
+void
+evhttp_request_free(struct evhttp_request *req)
+{
+	if (req->remote_host != NULL)
+		free(req->remote_host);
+	if (req->uri != NULL)
+		free(req->uri);
+	if (req->response_code_line != NULL)
+		free(req->response_code_line);
+
+	evhttp_clear_headers(req->input_headers);
+	free(req->input_headers);
+
+	evhttp_clear_headers(req->output_headers);
+	free(req->output_headers);
+
+	if (req->input_buffer != NULL)
+		evbuffer_free(req->input_buffer);
+
+	if (req->output_buffer != NULL)
+		evbuffer_free(req->output_buffer);
+
+	free(req);
+}
+
+void
+evhttp_request_set_chunked_cb(struct evhttp_request *req,
+    void (*cb)(struct evhttp_request *, void *))
+{
+	req->chunk_cb = cb;
+}
+
+/*
+ * Allows for inspection of the request URI
+ */
+
+const char *
+evhttp_request_uri(struct evhttp_request *req) {
+	if (req->uri == NULL)
+		event_debug(("%s: request %p has no uri\n", __func__, req));
+	return (req->uri);
+}
+
+/*
+ * Takes a file descriptor to read a request from.
+ * The callback is executed once the whole request has been read.
+ */
+
+static struct evhttp_connection*
+evhttp_get_request_connection(
+	struct evhttp* http,
+	int fd, struct sockaddr *sa, socklen_t salen)
+{
+	struct evhttp_connection *evcon;
+	char *hostname = NULL, *portname = NULL;
+
+	name_from_addr(sa, salen, &hostname, &portname);
+	if (hostname == NULL || portname == NULL) {
+		if (hostname) free(hostname);
+		if (portname) free(portname);
+		return (NULL);
+	}
+
+	event_debug(("%s: new request from %s:%s on %d\n",
+			__func__, hostname, portname, fd));
+
+	/* we need a connection object to put the http request on */
+	evcon = evhttp_connection_new(hostname, atoi(portname));
+	free(hostname);
+	free(portname);
+	if (evcon == NULL)
+		return (NULL);
+
+	/* associate the base if we have one*/
+	evhttp_connection_set_base(evcon, http->base);
+
+	evcon->flags |= EVHTTP_CON_INCOMING;
+	evcon->state = EVCON_READING_FIRSTLINE;
+	
+	evcon->fd = fd;
+
+	return (evcon);
+}
+
+static int
+evhttp_associate_new_request_with_connection(struct evhttp_connection *evcon)
+{
+	struct evhttp *http = evcon->http_server;
+	struct evhttp_request *req;
+	if ((req = evhttp_request_new(evhttp_handle_request, http)) == NULL)
+		return (-1);
+
+	req->evcon = evcon;	/* the request ends up owning the connection */
+	req->flags |= EVHTTP_REQ_OWN_CONNECTION;
+	
+	TAILQ_INSERT_TAIL(&evcon->requests, req, next);
+	
+	req->kind = EVHTTP_REQUEST;
+	
+	if ((req->remote_host = strdup(evcon->address)) == NULL)
+		event_err(1, "%s: strdup", __func__);
+	req->remote_port = evcon->port;
+
+	evhttp_start_read(evcon);
+	
+	return (0);
+}
+
+void
+evhttp_get_request(struct evhttp *http, int fd,
+    struct sockaddr *sa, socklen_t salen)
+{
+	struct evhttp_connection *evcon;
+
+	evcon = evhttp_get_request_connection(http, fd, sa, salen);
+	if (evcon == NULL)
+		return;
+
+	/* the timeout can be used by the server to close idle connections */
+	if (http->timeout != -1)
+		evhttp_connection_set_timeout(evcon, http->timeout);
+
+	/* 
+	 * if we want to accept more than one request on a connection,
+	 * we need to know which http server it belongs to.
+	 */
+	evcon->http_server = http;
+	TAILQ_INSERT_TAIL(&http->connections, evcon, next);
+	
+	if (evhttp_associate_new_request_with_connection(evcon) == -1)
+		evhttp_connection_free(evcon);
+}
+
+
+/*
+ * Network helper functions that we do not want to export to the rest of
+ * the world.
+ */
+#if 0 /* Unused */
+static struct addrinfo *
+addr_from_name(char *address)
+{
+#ifdef HAVE_GETADDRINFO
+        struct addrinfo ai, *aitop;
+        int ai_result;
+
+        memset(&ai, 0, sizeof(ai));
+        ai.ai_family = AF_INET;
+        ai.ai_socktype = SOCK_RAW;
+        ai.ai_flags = 0;
+        if ((ai_result = getaddrinfo(address, NULL, &ai, &aitop)) != 0) {
+                if ( ai_result == EAI_SYSTEM )
+                        event_warn("getaddrinfo");
+                else
+                        event_warnx("getaddrinfo: %s", gai_strerror(ai_result));
+        }
+
+	return (aitop);
+#else
+	assert(0);
+	return NULL; /* XXXXX Use gethostbyname, if this function is ever used. */
+#endif
+}
+#endif
+
+static void
+name_from_addr(struct sockaddr *sa, socklen_t salen,
+    char **phost, char **pport)
+{
+	char ntop[NI_MAXHOST];
+	char strport[NI_MAXSERV];
+	int ni_result;
+
+#ifdef HAVE_GETNAMEINFO
+	ni_result = getnameinfo(sa, salen,
+		ntop, sizeof(ntop), strport, sizeof(strport),
+		NI_NUMERICHOST|NI_NUMERICSERV);
+	
+	if (ni_result != 0) {
+		if (ni_result == EAI_SYSTEM)
+			event_err(1, "getnameinfo failed");
+		else
+			event_errx(1, "getnameinfo failed: %s", gai_strerror(ni_result));
+		return;
+	}
+#else
+	ni_result = fake_getnameinfo(sa, salen,
+		ntop, sizeof(ntop), strport, sizeof(strport),
+		NI_NUMERICHOST|NI_NUMERICSERV);
+	if (ni_result != 0)
+			return;
+#endif
+	*phost = strdup(ntop);
+	*pport = strdup(strport);
+}
+
+/* Either connect or bind */
+
+static int
+bind_socket_ai(struct addrinfo *ai, int reuse)
+{
+        int fd, on = 1, r;
+	int serrno;
+
+        /* Create listen socket */
+        fd = socket(AF_INET, SOCK_STREAM, 0);
+        if (fd == -1) {
+                event_warn("socket");
+                return (-1);
+        }
+
+        if (evutil_make_socket_nonblocking(fd) < 0)
+                goto out;
+
+#ifndef WIN32
+        if (fcntl(fd, F_SETFD, 1) == -1) {
+                event_warn("fcntl(F_SETFD)");
+                goto out;
+        }
+#endif
+
+        setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, (void *)&on, sizeof(on));
+	if (reuse) {
+		setsockopt(fd, SOL_SOCKET, SO_REUSEADDR,
+		    (void *)&on, sizeof(on));
+	}
+
+	r = bind(fd, ai->ai_addr, ai->ai_addrlen);
+	if (r == -1)
+		goto out;
+
+	return (fd);
+
+ out:
+	serrno = EVUTIL_SOCKET_ERROR();
+	EVUTIL_CLOSESOCKET(fd);
+	EVUTIL_SET_SOCKET_ERROR(serrno);
+	return (-1);
+}
+
+static struct addrinfo *
+make_addrinfo(const char *address, u_short port)
+{
+        struct addrinfo *aitop = NULL;
+
+#ifdef HAVE_GETADDRINFO
+        struct addrinfo ai;
+        char strport[NI_MAXSERV];
+        int ai_result;
+
+        memset(&ai, 0, sizeof(ai));
+        ai.ai_family = AF_INET;
+        ai.ai_socktype = SOCK_STREAM;
+        ai.ai_flags = AI_PASSIVE;  /* turn NULL host name into INADDR_ANY */
+        evutil_snprintf(strport, sizeof(strport), "%d", port);
+        if ((ai_result = getaddrinfo(address, strport, &ai, &aitop)) != 0) {
+                if ( ai_result == EAI_SYSTEM )
+                        event_warn("getaddrinfo");
+                else
+                        event_warnx("getaddrinfo: %s", gai_strerror(ai_result));
+		return (NULL);
+        }
+#else
+	static int cur;
+	static struct addrinfo ai[2]; /* We will be returning the address of some of this memory so it has to last even after this call. */
+	if (++cur == 2) cur = 0;   /* allow calling this function twice */
+
+	if (fake_getaddrinfo(address, &ai[cur]) < 0) {
+		event_warn("fake_getaddrinfo");
+		return (NULL);
+	}
+	aitop = &ai[cur];
+	((struct sockaddr_in *) aitop->ai_addr)->sin_port = htons(port);
+#endif
+
+	return (aitop);
+}
+
+static int
+bind_socket(const char *address, u_short port, int reuse)
+{
+	int fd;
+	struct addrinfo *aitop = make_addrinfo(address, port);
+
+	if (aitop == NULL)
+		return (-1);
+
+	fd = bind_socket_ai(aitop, reuse);
+
+#ifdef HAVE_GETADDRINFO
+	freeaddrinfo(aitop);
+#else
+	fake_freeaddrinfo(aitop);
+#endif
+
+	return (fd);
+}
+
+static int
+socket_connect(int fd, const char *address, unsigned short port)
+{
+	struct addrinfo *ai = make_addrinfo(address, port);
+	int res = -1;
+
+	if (ai == NULL) {
+		event_debug(("%s: make_addrinfo: \"%s:%d\"",
+			__func__, address, port));
+		return (-1);
+	}
+
+	if (connect(fd, ai->ai_addr, ai->ai_addrlen) == -1) {
+#ifdef WIN32
+		int tmp_error = WSAGetLastError();
+		if (tmp_error != WSAEWOULDBLOCK && tmp_error != WSAEINVAL &&
+		    tmp_error != WSAEINPROGRESS) {
+			goto out;
+		}
+#else
+		if (errno != EINPROGRESS) {
+			goto out;
+		}
+#endif
+	}
+
+	/* everything is fine */
+	res = 0;
+
+out:
+#ifdef HAVE_GETADDRINFO
+	freeaddrinfo(ai);
+#else
+	fake_freeaddrinfo(ai);
+#endif
+
+	return (res);
+}
diff --git a/libevent/install-sh b/libevent/install-sh
new file mode 100644
index 0000000..1a83534
--- /dev/null
+++ b/libevent/install-sh
@@ -0,0 +1,323 @@
+#!/bin/sh
+# install - install a program, script, or datafile
+
+scriptversion=2005-02-02.21
+
+# This originates from X11R5 (mit/util/scripts/install.sh), which was
+# later released in X11R6 (xc/config/util/install.sh) with the
+# following copyright and license.
+#
+# Copyright (C) 1994 X Consortium
+#
+# Permission is hereby granted, free of charge, to any person obtaining a copy
+# of this software and associated documentation files (the "Software"), to
+# deal in the Software without restriction, including without limitation the
+# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
+# sell copies of the Software, and to permit persons to whom the Software is
+# furnished to do so, subject to the following conditions:
+#
+# The above copyright notice and this permission notice shall be included in
+# all copies or substantial portions of the Software.
+#
+# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
+# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
+# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
+# X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
+# AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNEC-
+# TION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
+#
+# Except as contained in this notice, the name of the X Consortium shall not
+# be used in advertising or otherwise to promote the sale, use or other deal-
+# ings in this Software without prior written authorization from the X Consor-
+# tium.
+#
+#
+# FSF changes to this file are in the public domain.
+#
+# Calling this script install-sh is preferred over install.sh, to prevent
+# `make' implicit rules from creating a file called install from it
+# when there is no Makefile.
+#
+# This script is compatible with the BSD install script, but was written
+# from scratch.  It can only install one file at a time, a restriction
+# shared with many OS's install programs.
+
+# set DOITPROG to echo to test this script
+
+# Don't use :- since 4.3BSD and earlier shells don't like it.
+doit="${DOITPROG-}"
+
+# put in absolute paths if you don't have them in your path; or use env. vars.
+
+mvprog="${MVPROG-mv}"
+cpprog="${CPPROG-cp}"
+chmodprog="${CHMODPROG-chmod}"
+chownprog="${CHOWNPROG-chown}"
+chgrpprog="${CHGRPPROG-chgrp}"
+stripprog="${STRIPPROG-strip}"
+rmprog="${RMPROG-rm}"
+mkdirprog="${MKDIRPROG-mkdir}"
+
+chmodcmd="$chmodprog 0755"
+chowncmd=
+chgrpcmd=
+stripcmd=
+rmcmd="$rmprog -f"
+mvcmd="$mvprog"
+src=
+dst=
+dir_arg=
+dstarg=
+no_target_directory=
+
+usage="Usage: $0 [OPTION]... [-T] SRCFILE DSTFILE
+   or: $0 [OPTION]... SRCFILES... DIRECTORY
+   or: $0 [OPTION]... -t DIRECTORY SRCFILES...
+   or: $0 [OPTION]... -d DIRECTORIES...
+
+In the 1st form, copy SRCFILE to DSTFILE.
+In the 2nd and 3rd, copy all SRCFILES to DIRECTORY.
+In the 4th, create DIRECTORIES.
+
+Options:
+-c         (ignored)
+-d         create directories instead of installing files.
+-g GROUP   $chgrpprog installed files to GROUP.
+-m MODE    $chmodprog installed files to MODE.
+-o USER    $chownprog installed files to USER.
+-s         $stripprog installed files.
+-t DIRECTORY  install into DIRECTORY.
+-T         report an error if DSTFILE is a directory.
+--help     display this help and exit.
+--version  display version info and exit.
+
+Environment variables override the default commands:
+  CHGRPPROG CHMODPROG CHOWNPROG CPPROG MKDIRPROG MVPROG RMPROG STRIPPROG
+"
+
+while test -n "$1"; do
+  case $1 in
+    -c) shift
+        continue;;
+
+    -d) dir_arg=true
+        shift
+        continue;;
+
+    -g) chgrpcmd="$chgrpprog $2"
+        shift
+        shift
+        continue;;
+
+    --help) echo "$usage"; exit $?;;
+
+    -m) chmodcmd="$chmodprog $2"
+        shift
+        shift
+        continue;;
+
+    -o) chowncmd="$chownprog $2"
+        shift
+        shift
+        continue;;
+
+    -s) stripcmd=$stripprog
+        shift
+        continue;;
+
+    -t) dstarg=$2
+	shift
+	shift
+	continue;;
+
+    -T) no_target_directory=true
+	shift
+	continue;;
+
+    --version) echo "$0 $scriptversion"; exit $?;;
+
+    *)  # When -d is used, all remaining arguments are directories to create.
+	# When -t is used, the destination is already specified.
+	test -n "$dir_arg$dstarg" && break
+        # Otherwise, the last argument is the destination.  Remove it from $@.
+	for arg
+	do
+          if test -n "$dstarg"; then
+	    # $@ is not empty: it contains at least $arg.
+	    set fnord "$@" "$dstarg"
+	    shift # fnord
+	  fi
+	  shift # arg
+	  dstarg=$arg
+	done
+	break;;
+  esac
+done
+
+if test -z "$1"; then
+  if test -z "$dir_arg"; then
+    echo "$0: no input file specified." >&2
+    exit 1
+  fi
+  # It's OK to call `install-sh -d' without argument.
+  # This can happen when creating conditional directories.
+  exit 0
+fi
+
+for src
+do
+  # Protect names starting with `-'.
+  case $src in
+    -*) src=./$src ;;
+  esac
+
+  if test -n "$dir_arg"; then
+    dst=$src
+    src=
+
+    if test -d "$dst"; then
+      mkdircmd=:
+      chmodcmd=
+    else
+      mkdircmd=$mkdirprog
+    fi
+  else
+    # Waiting for this to be detected by the "$cpprog $src $dsttmp" command
+    # might cause directories to be created, which would be especially bad
+    # if $src (and thus $dsttmp) contains '*'.
+    if test ! -f "$src" && test ! -d "$src"; then
+      echo "$0: $src does not exist." >&2
+      exit 1
+    fi
+
+    if test -z "$dstarg"; then
+      echo "$0: no destination specified." >&2
+      exit 1
+    fi
+
+    dst=$dstarg
+    # Protect names starting with `-'.
+    case $dst in
+      -*) dst=./$dst ;;
+    esac
+
+    # If destination is a directory, append the input filename; won't work
+    # if double slashes aren't ignored.
+    if test -d "$dst"; then
+      if test -n "$no_target_directory"; then
+	echo "$0: $dstarg: Is a directory" >&2
+	exit 1
+      fi
+      dst=$dst/`basename "$src"`
+    fi
+  fi
+
+  # This sed command emulates the dirname command.
+  dstdir=`echo "$dst" | sed -e 's,/*$,,;s,[^/]*$,,;s,/*$,,;s,^$,.,'`
+
+  # Make sure that the destination directory exists.
+
+  # Skip lots of stat calls in the usual case.
+  if test ! -d "$dstdir"; then
+    defaultIFS='
+	 '
+    IFS="${IFS-$defaultIFS}"
+
+    oIFS=$IFS
+    # Some sh's can't handle IFS=/ for some reason.
+    IFS='%'
+    set x `echo "$dstdir" | sed -e 's@/@%@g' -e 's@^%@/@'`
+    shift
+    IFS=$oIFS
+
+    pathcomp=
+
+    while test $# -ne 0 ; do
+      pathcomp=$pathcomp$1
+      shift
+      if test ! -d "$pathcomp"; then
+        $mkdirprog "$pathcomp"
+	# mkdir can fail with a `File exist' error in case several
+	# install-sh are creating the directory concurrently.  This
+	# is OK.
+	test -d "$pathcomp" || exit
+      fi
+      pathcomp=$pathcomp/
+    done
+  fi
+
+  if test -n "$dir_arg"; then
+    $doit $mkdircmd "$dst" \
+      && { test -z "$chowncmd" || $doit $chowncmd "$dst"; } \
+      && { test -z "$chgrpcmd" || $doit $chgrpcmd "$dst"; } \
+      && { test -z "$stripcmd" || $doit $stripcmd "$dst"; } \
+      && { test -z "$chmodcmd" || $doit $chmodcmd "$dst"; }
+
+  else
+    dstfile=`basename "$dst"`
+
+    # Make a couple of temp file names in the proper directory.
+    dsttmp=$dstdir/_inst.$$_
+    rmtmp=$dstdir/_rm.$$_
+
+    # Trap to clean up those temp files at exit.
+    trap 'ret=$?; rm -f "$dsttmp" "$rmtmp" && exit $ret' 0
+    trap '(exit $?); exit' 1 2 13 15
+
+    # Copy the file name to the temp name.
+    $doit $cpprog "$src" "$dsttmp" &&
+
+    # and set any options; do chmod last to preserve setuid bits.
+    #
+    # If any of these fail, we abort the whole thing.  If we want to
+    # ignore errors from any of these, just make sure not to ignore
+    # errors from the above "$doit $cpprog $src $dsttmp" command.
+    #
+    { test -z "$chowncmd" || $doit $chowncmd "$dsttmp"; } \
+      && { test -z "$chgrpcmd" || $doit $chgrpcmd "$dsttmp"; } \
+      && { test -z "$stripcmd" || $doit $stripcmd "$dsttmp"; } \
+      && { test -z "$chmodcmd" || $doit $chmodcmd "$dsttmp"; } &&
+
+    # Now rename the file to the real destination.
+    { $doit $mvcmd -f "$dsttmp" "$dstdir/$dstfile" 2>/dev/null \
+      || {
+	   # The rename failed, perhaps because mv can't rename something else
+	   # to itself, or perhaps because mv is so ancient that it does not
+	   # support -f.
+
+	   # Now remove or move aside any old file at destination location.
+	   # We try this two ways since rm can't unlink itself on some
+	   # systems and the destination file might be busy for other
+	   # reasons.  In this case, the final cleanup might fail but the new
+	   # file should still install successfully.
+	   {
+	     if test -f "$dstdir/$dstfile"; then
+	       $doit $rmcmd -f "$dstdir/$dstfile" 2>/dev/null \
+	       || $doit $mvcmd -f "$dstdir/$dstfile" "$rmtmp" 2>/dev/null \
+	       || {
+		 echo "$0: cannot unlink or rename $dstdir/$dstfile" >&2
+		 (exit 1); exit 1
+	       }
+	     else
+	       :
+	     fi
+	   } &&
+
+	   # Now rename the file to the real destination.
+	   $doit $mvcmd "$dsttmp" "$dstdir/$dstfile"
+	 }
+    }
+  fi || { (exit 1); exit 1; }
+done
+
+# The final little trick to "correctly" pass the exit status to the exit trap.
+{
+  (exit 0); exit 0
+}
+
+# Local variables:
+# eval: (add-hook 'write-file-hooks 'time-stamp)
+# time-stamp-start: "scriptversion="
+# time-stamp-format: "%:y-%02m-%02d.%02H"
+# time-stamp-end: "$"
+# End:
diff --git a/libevent/kqueue.c b/libevent/kqueue.c
new file mode 100644
index 0000000..38a1819
--- /dev/null
+++ b/libevent/kqueue.c
@@ -0,0 +1,450 @@
+/*	$OpenBSD: kqueue.c,v 1.5 2002/07/10 14:41:31 art Exp $	*/
+
+/*
+ * Copyright 2000-2002 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#include <sys/queue.h>
+#include <sys/event.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <errno.h>
+#include <assert.h>
+#ifdef HAVE_INTTYPES_H
+#include <inttypes.h>
+#endif
+
+/* Some platforms apparently define the udata field of struct kevent as
+ * intptr_t, whereas others define it as void*.  There doesn't seem to be an
+ * easy way to tell them apart via autoconf, so we need to use OS macros. */
+#if defined(HAVE_INTTYPES_H) && !defined(__OpenBSD__) && !defined(__FreeBSD__) && !defined(__darwin__) && !defined(__APPLE__)
+#define PTR_TO_UDATA(x)	((intptr_t)(x))
+#else
+#define PTR_TO_UDATA(x)	(x)
+#endif
+
+#include "event.h"
+#include "event-internal.h"
+#include "log.h"
+#include "event-internal.h"
+
+#define EVLIST_X_KQINKERNEL	0x1000
+
+#define NEVENT		64
+
+struct kqop {
+	struct kevent *changes;
+	int nchanges;
+	struct kevent *events;
+	struct event_list evsigevents[NSIG];
+	int nevents;
+	int kq;
+	pid_t pid;
+};
+
+static void *kq_init	(struct event_base *);
+static int kq_add	(void *, struct event *);
+static int kq_del	(void *, struct event *);
+static int kq_dispatch	(struct event_base *, void *, struct timeval *);
+static int kq_insert	(struct kqop *, struct kevent *);
+static void kq_dealloc (struct event_base *, void *);
+
+const struct eventop kqops = {
+	"kqueue",
+	kq_init,
+	kq_add,
+	kq_del,
+	kq_dispatch,
+	kq_dealloc,
+	1 /* need reinit */
+};
+
+static void *
+kq_init(struct event_base *base)
+{
+	int i, kq;
+	struct kqop *kqueueop;
+
+	/* Disable kqueue when this environment variable is set */
+	if (getenv("EVENT_NOKQUEUE"))
+		return (NULL);
+
+	if (!(kqueueop = calloc(1, sizeof(struct kqop))))
+		return (NULL);
+
+	/* Initalize the kernel queue */
+	
+	if ((kq = kqueue()) == -1) {
+		event_warn("kqueue");
+		free (kqueueop);
+		return (NULL);
+	}
+
+	kqueueop->kq = kq;
+
+	kqueueop->pid = getpid();
+
+	/* Initalize fields */
+	kqueueop->changes = malloc(NEVENT * sizeof(struct kevent));
+	if (kqueueop->changes == NULL) {
+		free (kqueueop);
+		return (NULL);
+	}
+	kqueueop->events = malloc(NEVENT * sizeof(struct kevent));
+	if (kqueueop->events == NULL) {
+		free (kqueueop->changes);
+		free (kqueueop);
+		return (NULL);
+	}
+	kqueueop->nevents = NEVENT;
+
+	/* we need to keep track of multiple events per signal */
+	for (i = 0; i < NSIG; ++i) {
+		TAILQ_INIT(&kqueueop->evsigevents[i]);
+	}
+
+	/* Check for Mac OS X kqueue bug. */
+	kqueueop->changes[0].ident = -1;
+	kqueueop->changes[0].filter = EVFILT_READ;
+	kqueueop->changes[0].flags = EV_ADD;
+	/* 
+	 * If kqueue works, then kevent will succeed, and it will
+	 * stick an error in events[0].  If kqueue is broken, then
+	 * kevent will fail.
+	 */
+	if (kevent(kq,
+		kqueueop->changes, 1, kqueueop->events, NEVENT, NULL) != 1 ||
+	    kqueueop->events[0].ident != -1 ||
+	    kqueueop->events[0].flags != EV_ERROR) {
+		event_warn("%s: detected broken kqueue; not using.", __func__);
+		free(kqueueop->changes);
+		free(kqueueop->events);
+		free(kqueueop);
+		close(kq);
+		return (NULL);
+	}
+
+	return (kqueueop);
+}
+
+static int
+kq_insert(struct kqop *kqop, struct kevent *kev)
+{
+	int nevents = kqop->nevents;
+
+	if (kqop->nchanges == nevents) {
+		struct kevent *newchange;
+		struct kevent *newresult;
+
+		nevents *= 2;
+
+		newchange = realloc(kqop->changes,
+				    nevents * sizeof(struct kevent));
+		if (newchange == NULL) {
+			event_warn("%s: malloc", __func__);
+			return (-1);
+		}
+		kqop->changes = newchange;
+
+		newresult = realloc(kqop->events,
+				    nevents * sizeof(struct kevent));
+
+		/*
+		 * If we fail, we don't have to worry about freeing,
+		 * the next realloc will pick it up.
+		 */
+		if (newresult == NULL) {
+			event_warn("%s: malloc", __func__);
+			return (-1);
+		}
+		kqop->events = newresult;
+
+		kqop->nevents = nevents;
+	}
+
+	memcpy(&kqop->changes[kqop->nchanges++], kev, sizeof(struct kevent));
+
+	event_debug(("%s: fd %d %s%s",
+		__func__, (int)kev->ident, 
+		kev->filter == EVFILT_READ ? "EVFILT_READ" : "EVFILT_WRITE",
+		kev->flags == EV_DELETE ? " (del)" : ""));
+
+	return (0);
+}
+
+static void
+kq_sighandler(int sig)
+{
+	/* Do nothing here */
+}
+
+static int
+kq_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	struct kqop *kqop = arg;
+	struct kevent *changes = kqop->changes;
+	struct kevent *events = kqop->events;
+	struct event *ev;
+	struct timespec ts, *ts_p = NULL;
+	int i, res;
+
+	if (tv != NULL) {
+		TIMEVAL_TO_TIMESPEC(tv, &ts);
+		ts_p = &ts;
+	}
+
+	res = kevent(kqop->kq, changes, kqop->nchanges,
+	    events, kqop->nevents, ts_p);
+	kqop->nchanges = 0;
+	if (res == -1) {
+		if (errno != EINTR) {
+                        event_warn("kevent");
+			return (-1);
+		}
+
+		return (0);
+	}
+
+	event_debug(("%s: kevent reports %d", __func__, res));
+
+	for (i = 0; i < res; i++) {
+		int which = 0;
+
+		if (events[i].flags & EV_ERROR) {
+			/* 
+			 * Error messages that can happen, when a delete fails.
+			 *   EBADF happens when the file discriptor has been
+			 *   closed,
+			 *   ENOENT when the file discriptor was closed and
+			 *   then reopened.
+			 *   EINVAL for some reasons not understood; EINVAL
+			 *   should not be returned ever; but FreeBSD does :-\
+			 * An error is also indicated when a callback deletes
+			 * an event we are still processing.  In that case
+			 * the data field is set to ENOENT.
+			 */
+			if (events[i].data == EBADF ||
+			    events[i].data == EINVAL ||
+			    events[i].data == ENOENT)
+				continue;
+			errno = events[i].data;
+			return (-1);
+		}
+
+		if (events[i].filter == EVFILT_READ) {
+			which |= EV_READ;
+		} else if (events[i].filter == EVFILT_WRITE) {
+			which |= EV_WRITE;
+		} else if (events[i].filter == EVFILT_SIGNAL) {
+			which |= EV_SIGNAL;
+		}
+
+		if (!which)
+			continue;
+
+		if (events[i].filter == EVFILT_SIGNAL) {
+			struct event_list *head =
+			    (struct event_list *)events[i].udata;
+			TAILQ_FOREACH(ev, head, ev_signal_next) {
+				event_active(ev, which, events[i].data);
+			}
+		} else {
+			ev = (struct event *)events[i].udata;
+
+			if (!(ev->ev_events & EV_PERSIST))
+				ev->ev_flags &= ~EVLIST_X_KQINKERNEL;
+
+			event_active(ev, which, 1);
+		}
+	}
+
+	return (0);
+}
+
+
+static int
+kq_add(void *arg, struct event *ev)
+{
+	struct kqop *kqop = arg;
+	struct kevent kev;
+
+	if (ev->ev_events & EV_SIGNAL) {
+		int nsignal = EVENT_SIGNAL(ev);
+
+		assert(nsignal >= 0 && nsignal < NSIG);
+		if (TAILQ_EMPTY(&kqop->evsigevents[nsignal])) {
+			struct timespec timeout = { 0, 0 };
+			
+			memset(&kev, 0, sizeof(kev));
+			kev.ident = nsignal;
+			kev.filter = EVFILT_SIGNAL;
+			kev.flags = EV_ADD;
+			kev.udata = PTR_TO_UDATA(&kqop->evsigevents[nsignal]);
+			
+			/* Be ready for the signal if it is sent any
+			 * time between now and the next call to
+			 * kq_dispatch. */
+			if (kevent(kqop->kq, &kev, 1, NULL, 0, &timeout) == -1)
+				return (-1);
+			
+			if (_evsignal_set_handler(ev->ev_base, nsignal,
+				kq_sighandler) == -1)
+				return (-1);
+		}
+
+		TAILQ_INSERT_TAIL(&kqop->evsigevents[nsignal], ev,
+		    ev_signal_next);
+		ev->ev_flags |= EVLIST_X_KQINKERNEL;
+		return (0);
+	}
+
+	if (ev->ev_events & EV_READ) {
+ 		memset(&kev, 0, sizeof(kev));
+		kev.ident = ev->ev_fd;
+		kev.filter = EVFILT_READ;
+#ifdef NOTE_EOF
+		/* Make it behave like select() and poll() */
+		kev.fflags = NOTE_EOF;
+#endif
+		kev.flags = EV_ADD;
+		if (!(ev->ev_events & EV_PERSIST))
+			kev.flags |= EV_ONESHOT;
+		kev.udata = PTR_TO_UDATA(ev);
+		
+		if (kq_insert(kqop, &kev) == -1)
+			return (-1);
+
+		ev->ev_flags |= EVLIST_X_KQINKERNEL;
+	}
+
+	if (ev->ev_events & EV_WRITE) {
+ 		memset(&kev, 0, sizeof(kev));
+		kev.ident = ev->ev_fd;
+		kev.filter = EVFILT_WRITE;
+		kev.flags = EV_ADD;
+		if (!(ev->ev_events & EV_PERSIST))
+			kev.flags |= EV_ONESHOT;
+		kev.udata = PTR_TO_UDATA(ev);
+		
+		if (kq_insert(kqop, &kev) == -1)
+			return (-1);
+
+		ev->ev_flags |= EVLIST_X_KQINKERNEL;
+	}
+
+	return (0);
+}
+
+static int
+kq_del(void *arg, struct event *ev)
+{
+	struct kqop *kqop = arg;
+	struct kevent kev;
+
+	if (!(ev->ev_flags & EVLIST_X_KQINKERNEL))
+		return (0);
+
+	if (ev->ev_events & EV_SIGNAL) {
+		int nsignal = EVENT_SIGNAL(ev);
+		struct timespec timeout = { 0, 0 };
+
+		assert(nsignal >= 0 && nsignal < NSIG);
+		TAILQ_REMOVE(&kqop->evsigevents[nsignal], ev, ev_signal_next);
+		if (TAILQ_EMPTY(&kqop->evsigevents[nsignal])) {
+			memset(&kev, 0, sizeof(kev));
+			kev.ident = nsignal;
+			kev.filter = EVFILT_SIGNAL;
+			kev.flags = EV_DELETE;
+		
+			/* Because we insert signal events
+			 * immediately, we need to delete them
+			 * immediately, too */
+			if (kevent(kqop->kq, &kev, 1, NULL, 0, &timeout) == -1)
+				return (-1);
+
+			if (_evsignal_restore_handler(ev->ev_base,
+				nsignal) == -1)
+				return (-1);
+		}
+
+		ev->ev_flags &= ~EVLIST_X_KQINKERNEL;
+		return (0);
+	}
+
+	if (ev->ev_events & EV_READ) {
+ 		memset(&kev, 0, sizeof(kev));
+		kev.ident = ev->ev_fd;
+		kev.filter = EVFILT_READ;
+		kev.flags = EV_DELETE;
+		
+		if (kq_insert(kqop, &kev) == -1)
+			return (-1);
+
+		ev->ev_flags &= ~EVLIST_X_KQINKERNEL;
+	}
+
+	if (ev->ev_events & EV_WRITE) {
+ 		memset(&kev, 0, sizeof(kev));
+		kev.ident = ev->ev_fd;
+		kev.filter = EVFILT_WRITE;
+		kev.flags = EV_DELETE;
+		
+		if (kq_insert(kqop, &kev) == -1)
+			return (-1);
+
+		ev->ev_flags &= ~EVLIST_X_KQINKERNEL;
+	}
+
+	return (0);
+}
+
+static void
+kq_dealloc(struct event_base *base, void *arg)
+{
+	struct kqop *kqop = arg;
+
+	if (kqop->changes)
+		free(kqop->changes);
+	if (kqop->events)
+		free(kqop->events);
+
+	if (kqop->kq >= 0 && kqop->pid == getpid())
+		close(kqop->kq);
+	memset(kqop, 0, sizeof(struct kqop));
+	free(kqop);
+}
diff --git a/libevent/log.c b/libevent/log.c
new file mode 100644
index 0000000..b62a619
--- /dev/null
+++ b/libevent/log.c
@@ -0,0 +1,187 @@
+/*	$OpenBSD: err.c,v 1.2 2002/06/25 15:50:15 mickey Exp $	*/
+
+/*
+ * log.c
+ *
+ * Based on err.c, which was adapted from OpenBSD libc *err* *warn* code.
+ *
+ * Copyright (c) 2005 Nick Mathewson <nickm@freehaven.net>
+ *
+ * Copyright (c) 2000 Dug Song <dugsong@monkey.org>
+ *
+ * Copyright (c) 1993
+ *	The Regents of the University of California.  All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. Neither the name of the University nor the names of its contributors
+ *    may be used to endorse or promote products derived from this software
+ *    without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
+ * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
+ * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
+ * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
+ * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
+ * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
+ * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
+ * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
+ * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
+ * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
+ * SUCH DAMAGE.
+ */
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef WIN32
+#define WIN32_LEAN_AND_MEAN
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+#endif
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#include <stdio.h>
+#include <stdlib.h>
+#include <stdarg.h>
+#include <string.h>
+#include <errno.h>
+#include "event.h"
+
+#include "log.h"
+#include "evutil.h"
+
+static void _warn_helper(int severity, int log_errno, const char *fmt,
+                         va_list ap);
+static void event_log(int severity, const char *msg);
+
+void
+event_err(int eval, const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_ERR, errno, fmt, ap);
+	va_end(ap);
+	exit(eval);
+}
+
+void
+event_warn(const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_WARN, errno, fmt, ap);
+	va_end(ap);
+}
+
+void
+event_errx(int eval, const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_ERR, -1, fmt, ap);
+	va_end(ap);
+	exit(eval);
+}
+
+void
+event_warnx(const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_WARN, -1, fmt, ap);
+	va_end(ap);
+}
+
+void
+event_msgx(const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_MSG, -1, fmt, ap);
+	va_end(ap);
+}
+
+void
+_event_debugx(const char *fmt, ...)
+{
+	va_list ap;
+	
+	va_start(ap, fmt);
+	_warn_helper(_EVENT_LOG_DEBUG, -1, fmt, ap);
+	va_end(ap);
+}
+
+static void
+_warn_helper(int severity, int log_errno, const char *fmt, va_list ap)
+{
+	char buf[1024];
+	size_t len;
+
+	if (fmt != NULL)
+		evutil_vsnprintf(buf, sizeof(buf), fmt, ap);
+	else
+		buf[0] = '\0';
+
+	if (log_errno >= 0) {
+		len = strlen(buf);
+		if (len < sizeof(buf) - 3) {
+			evutil_snprintf(buf + len, sizeof(buf) - len, ": %s",
+			    strerror(log_errno));
+		}
+	}
+
+	event_log(severity, buf);
+}
+
+static event_log_cb log_fn = NULL;
+
+void
+event_set_log_callback(event_log_cb cb)
+{
+	log_fn = cb;
+}
+
+static void
+event_log(int severity, const char *msg)
+{
+	if (log_fn)
+		log_fn(severity, msg);
+	else {
+		const char *severity_str;
+		switch (severity) {
+		case _EVENT_LOG_DEBUG:
+			severity_str = "debug";
+			break;
+		case _EVENT_LOG_MSG:
+			severity_str = "msg";
+			break;
+		case _EVENT_LOG_WARN:
+			severity_str = "warn";
+			break;
+		case _EVENT_LOG_ERR:
+			severity_str = "err";
+			break;
+		default:
+			severity_str = "???";
+			break;
+		}
+		(void)fprintf(stderr, "[%s] %s\n", severity_str, msg);
+	}
+}
diff --git a/libevent/log.h b/libevent/log.h
new file mode 100644
index 0000000..7bc6632
--- /dev/null
+++ b/libevent/log.h
@@ -0,0 +1,51 @@
+/*
+ * Copyright (c) 2000-2004 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _LOG_H_
+#define _LOG_H_
+
+#ifdef __GNUC__
+#define EV_CHECK_FMT(a,b) __attribute__((format(printf, a, b)))
+#else
+#define EV_CHECK_FMT(a,b)
+#endif
+
+void event_err(int eval, const char *fmt, ...) EV_CHECK_FMT(2,3);
+void event_warn(const char *fmt, ...) EV_CHECK_FMT(1,2);
+void event_errx(int eval, const char *fmt, ...) EV_CHECK_FMT(2,3);
+void event_warnx(const char *fmt, ...) EV_CHECK_FMT(1,2);
+void event_msgx(const char *fmt, ...) EV_CHECK_FMT(1,2);
+void _event_debugx(const char *fmt, ...) EV_CHECK_FMT(1,2);
+
+#ifdef USE_DEBUG
+#define event_debug(x) _event_debugx x
+#else
+#define event_debug(x) do {;} while (0)
+#endif
+
+#undef EV_CHECK_FMT
+
+#endif
diff --git a/libevent/min_heap.h b/libevent/min_heap.h
new file mode 100644
index 0000000..d47e563
--- /dev/null
+++ b/libevent/min_heap.h
@@ -0,0 +1,139 @@
+/*
+ * Copyright (c) 2006 Maxim Yegorushkin <maxim.yegorushkin@gmail.com>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifndef _MIN_HEAP_H_
+#define _MIN_HEAP_H_
+
+#include "event.h"
+#include "evutil.h"
+
+typedef struct min_heap
+{
+    struct event** p;
+    unsigned n, a;
+} min_heap_t;
+
+static inline void           min_heap_ctor(min_heap_t* s);
+static inline void           min_heap_dtor(min_heap_t* s);
+static inline void           min_heap_elem_init(struct event* e);
+static inline int            min_heap_elem_greater(struct event *a, struct event *b);
+static inline int            min_heap_empty(min_heap_t* s);
+static inline unsigned       min_heap_size(min_heap_t* s);
+static inline struct event*  min_heap_top(min_heap_t* s);
+static inline int            min_heap_reserve(min_heap_t* s, unsigned n);
+static inline int            min_heap_push(min_heap_t* s, struct event* e);
+static inline struct event*  min_heap_pop(min_heap_t* s);
+static inline int            min_heap_erase(min_heap_t* s, struct event* e);
+static inline void           min_heap_shift_up_(min_heap_t* s, unsigned hole_index, struct event* e);
+static inline void           min_heap_shift_down_(min_heap_t* s, unsigned hole_index, struct event* e);
+
+int min_heap_elem_greater(struct event *a, struct event *b)
+{
+    return evutil_timercmp(&a->ev_timeout, &b->ev_timeout, >);
+}
+
+void min_heap_ctor(min_heap_t* s) { s->p = 0; s->n = 0; s->a = 0; }
+void min_heap_dtor(min_heap_t* s) { free(s->p); }
+void min_heap_elem_init(struct event* e) { e->min_heap_idx = -1; }
+int min_heap_empty(min_heap_t* s) { return 0u == s->n; }
+unsigned min_heap_size(min_heap_t* s) { return s->n; }
+struct event* min_heap_top(min_heap_t* s) { return s->n ? *s->p : 0; }
+
+int min_heap_push(min_heap_t* s, struct event* e)
+{
+    if(min_heap_reserve(s, s->n + 1))
+        return -1;
+    min_heap_shift_up_(s, s->n++, e);
+    return 0;
+}
+
+struct event* min_heap_pop(min_heap_t* s)
+{
+    if(s->n)
+    {
+        struct event* e = *s->p;
+        min_heap_shift_down_(s, 0u, s->p[--s->n]);
+        e->min_heap_idx = -1;
+        return e;
+    }
+    return 0;
+}
+
+int min_heap_erase(min_heap_t* s, struct event* e)
+{
+    if(((unsigned int)-1) != e->min_heap_idx)
+    {
+        min_heap_shift_down_(s, e->min_heap_idx, s->p[--s->n]);
+        e->min_heap_idx = -1;
+        return 0;
+    }
+    return -1;
+}
+
+int min_heap_reserve(min_heap_t* s, unsigned n)
+{
+    if(s->a < n)
+    {
+        struct event** p;
+        unsigned a = s->a ? s->a * 2 : 8;
+        if(a < n)
+            a = n;
+        if(!(p = (struct event**)realloc(s->p, a * sizeof *p)))
+            return -1;
+        s->p = p;
+        s->a = a;
+    }
+    return 0;
+}
+
+void min_heap_shift_up_(min_heap_t* s, unsigned hole_index, struct event* e)
+{
+    unsigned parent = (hole_index - 1) / 2;
+    while(hole_index && min_heap_elem_greater(s->p[parent], e))
+    {
+        (s->p[hole_index] = s->p[parent])->min_heap_idx = hole_index;
+        hole_index = parent;
+        parent = (hole_index - 1) / 2;
+    }
+    (s->p[hole_index] = e)->min_heap_idx = hole_index;
+}
+
+void min_heap_shift_down_(min_heap_t* s, unsigned hole_index, struct event* e)
+{
+    unsigned min_child = 2 * (hole_index + 1);
+    while(min_child <= s->n)
+	{
+        min_child -= min_child == s->n || min_heap_elem_greater(s->p[min_child], s->p[min_child - 1]);
+        if(!(min_heap_elem_greater(e, s->p[min_child])))
+            break;
+        (s->p[hole_index] = s->p[min_child])->min_heap_idx = hole_index;
+        hole_index = min_child;
+        min_child = 2 * (hole_index + 1);
+	}
+    min_heap_shift_up_(s, hole_index,  e);
+}
+
+#endif /* _MIN_HEAP_H_ */
diff --git a/libevent/missing b/libevent/missing
new file mode 100644
index 0000000..09edd88
--- /dev/null
+++ b/libevent/missing
@@ -0,0 +1,357 @@
+#! /bin/sh
+# Common stub for a few missing GNU programs while installing.
+
+scriptversion=2005-02-08.22
+
+# Copyright (C) 1996, 1997, 1999, 2000, 2002, 2003, 2004, 2005
+#   Free Software Foundation, Inc.
+# Originally by Fran,cois Pinard <pinard@iro.umontreal.ca>, 1996.
+
+# This program is free software; you can redistribute it and/or modify
+# it under the terms of the GNU General Public License as published by
+# the Free Software Foundation; either version 2, or (at your option)
+# any later version.
+
+# This program is distributed in the hope that it will be useful,
+# but WITHOUT ANY WARRANTY; without even the implied warranty of
+# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+# GNU General Public License for more details.
+
+# You should have received a copy of the GNU General Public License
+# along with this program; if not, write to the Free Software
+# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
+# 02111-1307, USA.
+
+# As a special exception to the GNU General Public License, if you
+# distribute this file as part of a program that contains a
+# configuration script generated by Autoconf, you may include it under
+# the same distribution terms that you use for the rest of that program.
+
+if test $# -eq 0; then
+  echo 1>&2 "Try \`$0 --help' for more information"
+  exit 1
+fi
+
+run=:
+
+# In the cases where this matters, `missing' is being run in the
+# srcdir already.
+if test -f configure.ac; then
+  configure_ac=configure.ac
+else
+  configure_ac=configure.in
+fi
+
+msg="missing on your system"
+
+case "$1" in
+--run)
+  # Try to run requested program, and just exit if it succeeds.
+  run=
+  shift
+  "$@" && exit 0
+  # Exit code 63 means version mismatch.  This often happens
+  # when the user try to use an ancient version of a tool on
+  # a file that requires a minimum version.  In this case we
+  # we should proceed has if the program had been absent, or
+  # if --run hadn't been passed.
+  if test $? = 63; then
+    run=:
+    msg="probably too old"
+  fi
+  ;;
+
+  -h|--h|--he|--hel|--help)
+    echo "\
+$0 [OPTION]... PROGRAM [ARGUMENT]...
+
+Handle \`PROGRAM [ARGUMENT]...' for when PROGRAM is missing, or return an
+error status if there is no known handling for PROGRAM.
+
+Options:
+  -h, --help      display this help and exit
+  -v, --version   output version information and exit
+  --run           try to run the given command, and emulate it if it fails
+
+Supported PROGRAM values:
+  aclocal      touch file \`aclocal.m4'
+  autoconf     touch file \`configure'
+  autoheader   touch file \`config.h.in'
+  automake     touch all \`Makefile.in' files
+  bison        create \`y.tab.[ch]', if possible, from existing .[ch]
+  flex         create \`lex.yy.c', if possible, from existing .c
+  help2man     touch the output file
+  lex          create \`lex.yy.c', if possible, from existing .c
+  makeinfo     touch the output file
+  tar          try tar, gnutar, gtar, then tar without non-portable flags
+  yacc         create \`y.tab.[ch]', if possible, from existing .[ch]
+
+Send bug reports to <bug-automake@gnu.org>."
+    exit $?
+    ;;
+
+  -v|--v|--ve|--ver|--vers|--versi|--versio|--version)
+    echo "missing $scriptversion (GNU Automake)"
+    exit $?
+    ;;
+
+  -*)
+    echo 1>&2 "$0: Unknown \`$1' option"
+    echo 1>&2 "Try \`$0 --help' for more information"
+    exit 1
+    ;;
+
+esac
+
+# Now exit if we have it, but it failed.  Also exit now if we
+# don't have it and --version was passed (most likely to detect
+# the program).
+case "$1" in
+  lex|yacc)
+    # Not GNU programs, they don't have --version.
+    ;;
+
+  tar)
+    if test -n "$run"; then
+       echo 1>&2 "ERROR: \`tar' requires --run"
+       exit 1
+    elif test "x$2" = "x--version" || test "x$2" = "x--help"; then
+       exit 1
+    fi
+    ;;
+
+  *)
+    if test -z "$run" && ($1 --version) > /dev/null 2>&1; then
+       # We have it, but it failed.
+       exit 1
+    elif test "x$2" = "x--version" || test "x$2" = "x--help"; then
+       # Could not run --version or --help.  This is probably someone
+       # running `$TOOL --version' or `$TOOL --help' to check whether
+       # $TOOL exists and not knowing $TOOL uses missing.
+       exit 1
+    fi
+    ;;
+esac
+
+# If it does not exist, or fails to run (possibly an outdated version),
+# try to emulate it.
+case "$1" in
+  aclocal*)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified \`acinclude.m4' or \`${configure_ac}'.  You might want
+         to install the \`Automake' and \`Perl' packages.  Grab them from
+         any GNU archive site."
+    touch aclocal.m4
+    ;;
+
+  autoconf)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified \`${configure_ac}'.  You might want to install the
+         \`Autoconf' and \`GNU m4' packages.  Grab them from any GNU
+         archive site."
+    touch configure
+    ;;
+
+  autoheader)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified \`acconfig.h' or \`${configure_ac}'.  You might want
+         to install the \`Autoconf' and \`GNU m4' packages.  Grab them
+         from any GNU archive site."
+    files=`sed -n 's/^[ ]*A[CM]_CONFIG_HEADER(\([^)]*\)).*/\1/p' ${configure_ac}`
+    test -z "$files" && files="config.h"
+    touch_files=
+    for f in $files; do
+      case "$f" in
+      *:*) touch_files="$touch_files "`echo "$f" |
+				       sed -e 's/^[^:]*://' -e 's/:.*//'`;;
+      *) touch_files="$touch_files $f.in";;
+      esac
+    done
+    touch $touch_files
+    ;;
+
+  automake*)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified \`Makefile.am', \`acinclude.m4' or \`${configure_ac}'.
+         You might want to install the \`Automake' and \`Perl' packages.
+         Grab them from any GNU archive site."
+    find . -type f -name Makefile.am -print |
+	   sed 's/\.am$/.in/' |
+	   while read f; do touch "$f"; done
+    ;;
+
+  autom4te)
+    echo 1>&2 "\
+WARNING: \`$1' is needed, but is $msg.
+         You might have modified some files without having the
+         proper tools for further handling them.
+         You can get \`$1' as part of \`Autoconf' from any GNU
+         archive site."
+
+    file=`echo "$*" | sed -n 's/.*--output[ =]*\([^ ]*\).*/\1/p'`
+    test -z "$file" && file=`echo "$*" | sed -n 's/.*-o[ ]*\([^ ]*\).*/\1/p'`
+    if test -f "$file"; then
+	touch $file
+    else
+	test -z "$file" || exec >$file
+	echo "#! /bin/sh"
+	echo "# Created by GNU Automake missing as a replacement of"
+	echo "#  $ $@"
+	echo "exit 0"
+	chmod +x $file
+	exit 1
+    fi
+    ;;
+
+  bison|yacc)
+    echo 1>&2 "\
+WARNING: \`$1' $msg.  You should only need it if
+         you modified a \`.y' file.  You may need the \`Bison' package
+         in order for those modifications to take effect.  You can get
+         \`Bison' from any GNU archive site."
+    rm -f y.tab.c y.tab.h
+    if [ $# -ne 1 ]; then
+        eval LASTARG="\${$#}"
+	case "$LASTARG" in
+	*.y)
+	    SRCFILE=`echo "$LASTARG" | sed 's/y$/c/'`
+	    if [ -f "$SRCFILE" ]; then
+	         cp "$SRCFILE" y.tab.c
+	    fi
+	    SRCFILE=`echo "$LASTARG" | sed 's/y$/h/'`
+	    if [ -f "$SRCFILE" ]; then
+	         cp "$SRCFILE" y.tab.h
+	    fi
+	  ;;
+	esac
+    fi
+    if [ ! -f y.tab.h ]; then
+	echo >y.tab.h
+    fi
+    if [ ! -f y.tab.c ]; then
+	echo 'main() { return 0; }' >y.tab.c
+    fi
+    ;;
+
+  lex|flex)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified a \`.l' file.  You may need the \`Flex' package
+         in order for those modifications to take effect.  You can get
+         \`Flex' from any GNU archive site."
+    rm -f lex.yy.c
+    if [ $# -ne 1 ]; then
+        eval LASTARG="\${$#}"
+	case "$LASTARG" in
+	*.l)
+	    SRCFILE=`echo "$LASTARG" | sed 's/l$/c/'`
+	    if [ -f "$SRCFILE" ]; then
+	         cp "$SRCFILE" lex.yy.c
+	    fi
+	  ;;
+	esac
+    fi
+    if [ ! -f lex.yy.c ]; then
+	echo 'main() { return 0; }' >lex.yy.c
+    fi
+    ;;
+
+  help2man)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+	 you modified a dependency of a manual page.  You may need the
+	 \`Help2man' package in order for those modifications to take
+	 effect.  You can get \`Help2man' from any GNU archive site."
+
+    file=`echo "$*" | sed -n 's/.*-o \([^ ]*\).*/\1/p'`
+    if test -z "$file"; then
+	file=`echo "$*" | sed -n 's/.*--output=\([^ ]*\).*/\1/p'`
+    fi
+    if [ -f "$file" ]; then
+	touch $file
+    else
+	test -z "$file" || exec >$file
+	echo ".ab help2man is required to generate this page"
+	exit 1
+    fi
+    ;;
+
+  makeinfo)
+    echo 1>&2 "\
+WARNING: \`$1' is $msg.  You should only need it if
+         you modified a \`.texi' or \`.texinfo' file, or any other file
+         indirectly affecting the aspect of the manual.  The spurious
+         call might also be the consequence of using a buggy \`make' (AIX,
+         DU, IRIX).  You might want to install the \`Texinfo' package or
+         the \`GNU make' package.  Grab either from any GNU archive site."
+    # The file to touch is that specified with -o ...
+    file=`echo "$*" | sed -n 's/.*-o \([^ ]*\).*/\1/p'`
+    if test -z "$file"; then
+      # ... or it is the one specified with @setfilename ...
+      infile=`echo "$*" | sed 's/.* \([^ ]*\) *$/\1/'`
+      file=`sed -n '/^@setfilename/ { s/.* \([^ ]*\) *$/\1/; p; q; }' $infile`
+      # ... or it is derived from the source name (dir/f.texi becomes f.info)
+      test -z "$file" && file=`echo "$infile" | sed 's,.*/,,;s,.[^.]*$,,'`.info
+    fi
+    touch $file
+    ;;
+
+  tar)
+    shift
+
+    # We have already tried tar in the generic part.
+    # Look for gnutar/gtar before invocation to avoid ugly error
+    # messages.
+    if (gnutar --version > /dev/null 2>&1); then
+       gnutar "$@" && exit 0
+    fi
+    if (gtar --version > /dev/null 2>&1); then
+       gtar "$@" && exit 0
+    fi
+    firstarg="$1"
+    if shift; then
+	case "$firstarg" in
+	*o*)
+	    firstarg=`echo "$firstarg" | sed s/o//`
+	    tar "$firstarg" "$@" && exit 0
+	    ;;
+	esac
+	case "$firstarg" in
+	*h*)
+	    firstarg=`echo "$firstarg" | sed s/h//`
+	    tar "$firstarg" "$@" && exit 0
+	    ;;
+	esac
+    fi
+
+    echo 1>&2 "\
+WARNING: I can't seem to be able to run \`tar' with the given arguments.
+         You may want to install GNU tar or Free paxutils, or check the
+         command line arguments."
+    exit 1
+    ;;
+
+  *)
+    echo 1>&2 "\
+WARNING: \`$1' is needed, and is $msg.
+         You might have modified some files without having the
+         proper tools for further handling them.  Check the \`README' file,
+         it often tells you about the needed prerequisites for installing
+         this package.  You may also peek at any GNU archive site, in case
+         some other package would contain this missing \`$1' program."
+    exit 1
+    ;;
+esac
+
+exit 0
+
+# Local variables:
+# eval: (add-hook 'write-file-hooks 'time-stamp)
+# time-stamp-start: "scriptversion="
+# time-stamp-format: "%:y-%02m-%02d.%02H"
+# time-stamp-end: "$"
+# End:
diff --git a/libevent/poll.c b/libevent/poll.c
new file mode 100644
index 0000000..b67c6ff
--- /dev/null
+++ b/libevent/poll.c
@@ -0,0 +1,374 @@
+/*	$OpenBSD: poll.c,v 1.2 2002/06/25 15:50:15 mickey Exp $	*/
+
+/*
+ * Copyright 2000-2003 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#include <sys/queue.h>
+#include <poll.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <errno.h>
+#ifdef CHECK_INVARIANTS
+#include <assert.h>
+#endif
+
+#include "event.h"
+#include "event-internal.h"
+#include "evsignal.h"
+#include "log.h"
+
+struct pollop {
+	int event_count;		/* Highest number alloc */
+	int nfds;                       /* Size of event_* */
+	int fd_count;                   /* Size of idxplus1_by_fd */
+	struct pollfd *event_set;
+	struct event **event_r_back;
+	struct event **event_w_back;
+	int *idxplus1_by_fd; /* Index into event_set by fd; we add 1 so
+			      * that 0 (which is easy to memset) can mean
+			      * "no entry." */
+};
+
+static void *poll_init	(struct event_base *);
+static int poll_add		(void *, struct event *);
+static int poll_del		(void *, struct event *);
+static int poll_dispatch	(struct event_base *, void *, struct timeval *);
+static void poll_dealloc	(struct event_base *, void *);
+
+const struct eventop pollops = {
+	"poll",
+	poll_init,
+	poll_add,
+	poll_del,
+	poll_dispatch,
+	poll_dealloc,
+    0
+};
+
+static void *
+poll_init(struct event_base *base)
+{
+	struct pollop *pollop;
+
+	/* Disable poll when this environment variable is set */
+	if (getenv("EVENT_NOPOLL"))
+		return (NULL);
+
+	if (!(pollop = calloc(1, sizeof(struct pollop))))
+		return (NULL);
+
+	evsignal_init(base);
+
+	return (pollop);
+}
+
+#ifdef CHECK_INVARIANTS
+static void
+poll_check_ok(struct pollop *pop)
+{
+	int i, idx;
+	struct event *ev;
+
+	for (i = 0; i < pop->fd_count; ++i) {
+		idx = pop->idxplus1_by_fd[i]-1;
+		if (idx < 0)
+			continue;
+		assert(pop->event_set[idx].fd == i);
+		if (pop->event_set[idx].events & POLLIN) {
+			ev = pop->event_r_back[idx];
+			assert(ev);
+			assert(ev->ev_events & EV_READ);
+			assert(ev->ev_fd == i);
+		}
+		if (pop->event_set[idx].events & POLLOUT) {
+			ev = pop->event_w_back[idx];
+			assert(ev);
+			assert(ev->ev_events & EV_WRITE);
+			assert(ev->ev_fd == i);
+		}
+	}
+	for (i = 0; i < pop->nfds; ++i) {
+		struct pollfd *pfd = &pop->event_set[i];
+		assert(pop->idxplus1_by_fd[pfd->fd] == i+1);
+	}
+}
+#else
+#define poll_check_ok(pop)
+#endif
+
+static int
+poll_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	int res, i, msec = -1, nfds;
+	struct pollop *pop = arg;
+
+	poll_check_ok(pop);
+
+	if (tv != NULL)
+		msec = tv->tv_sec * 1000 + (tv->tv_usec + 999) / 1000;
+
+	nfds = pop->nfds;
+	res = poll(pop->event_set, nfds, msec);
+
+	if (res == -1) {
+		if (errno != EINTR) {
+                        event_warn("poll");
+			return (-1);
+		}
+
+		evsignal_process(base);
+		return (0);
+	} else if (base->sig.evsignal_caught) {
+		evsignal_process(base);
+	}
+
+	event_debug(("%s: poll reports %d", __func__, res));
+
+	if (res == 0)
+		return (0);
+
+	for (i = 0; i < nfds; i++) {
+		int what = pop->event_set[i].revents;
+		struct event *r_ev = NULL, *w_ev = NULL;
+		if (!what)
+			continue;
+
+		res = 0;
+
+		/* If the file gets closed notify */
+		if (what & (POLLHUP|POLLERR))
+			what |= POLLIN|POLLOUT;
+		if (what & POLLIN) {
+			res |= EV_READ;
+			r_ev = pop->event_r_back[i];
+		}
+		if (what & POLLOUT) {
+			res |= EV_WRITE;
+			w_ev = pop->event_w_back[i];
+		}
+		if (res == 0)
+			continue;
+
+		if (r_ev && (res & r_ev->ev_events)) {
+			event_active(r_ev, res & r_ev->ev_events, 1);
+		}
+		if (w_ev && w_ev != r_ev && (res & w_ev->ev_events)) {
+			event_active(w_ev, res & w_ev->ev_events, 1);
+		}
+	}
+
+	return (0);
+}
+
+static int
+poll_add(void *arg, struct event *ev)
+{
+	struct pollop *pop = arg;
+	struct pollfd *pfd = NULL;
+	int i;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_add(ev));
+	if (!(ev->ev_events & (EV_READ|EV_WRITE)))
+		return (0);
+
+	poll_check_ok(pop);
+	if (pop->nfds + 1 >= pop->event_count) {
+		struct pollfd *tmp_event_set;
+		struct event **tmp_event_r_back;
+		struct event **tmp_event_w_back;
+		int tmp_event_count;
+
+		if (pop->event_count < 32)
+			tmp_event_count = 32;
+		else
+			tmp_event_count = pop->event_count * 2;
+
+		/* We need more file descriptors */
+		tmp_event_set = realloc(pop->event_set,
+				 tmp_event_count * sizeof(struct pollfd));
+		if (tmp_event_set == NULL) {
+			event_warn("realloc");
+			return (-1);
+		}
+		pop->event_set = tmp_event_set;
+
+		tmp_event_r_back = realloc(pop->event_r_back,
+			    tmp_event_count * sizeof(struct event *));
+		if (tmp_event_r_back == NULL) {
+			/* event_set overallocated; that's okay. */
+			event_warn("realloc");
+			return (-1);
+		}
+		pop->event_r_back = tmp_event_r_back;
+
+		tmp_event_w_back = realloc(pop->event_w_back,
+			    tmp_event_count * sizeof(struct event *));
+		if (tmp_event_w_back == NULL) {
+			/* event_set and event_r_back overallocated; that's
+			 * okay. */
+			event_warn("realloc");
+			return (-1);
+		}
+		pop->event_w_back = tmp_event_w_back;
+
+		pop->event_count = tmp_event_count;
+	}
+	if (ev->ev_fd >= pop->fd_count) {
+		int *tmp_idxplus1_by_fd;
+		int new_count;
+		if (pop->fd_count < 32)
+			new_count = 32;
+		else
+			new_count = pop->fd_count * 2;
+		while (new_count <= ev->ev_fd)
+			new_count *= 2;
+		tmp_idxplus1_by_fd =
+			realloc(pop->idxplus1_by_fd, new_count * sizeof(int));
+		if (tmp_idxplus1_by_fd == NULL) {
+			event_warn("realloc");
+			return (-1);
+		}
+		pop->idxplus1_by_fd = tmp_idxplus1_by_fd;
+		memset(pop->idxplus1_by_fd + pop->fd_count,
+		       0, sizeof(int)*(new_count - pop->fd_count));
+		pop->fd_count = new_count;
+	}
+
+	i = pop->idxplus1_by_fd[ev->ev_fd] - 1;
+	if (i >= 0) {
+		pfd = &pop->event_set[i];
+	} else {
+		i = pop->nfds++;
+		pfd = &pop->event_set[i];
+		pfd->events = 0;
+		pfd->fd = ev->ev_fd;
+		pop->event_w_back[i] = pop->event_r_back[i] = NULL;
+		pop->idxplus1_by_fd[ev->ev_fd] = i + 1;
+	}
+
+	pfd->revents = 0;
+	if (ev->ev_events & EV_WRITE) {
+		pfd->events |= POLLOUT;
+		pop->event_w_back[i] = ev;
+	}
+	if (ev->ev_events & EV_READ) {
+		pfd->events |= POLLIN;
+		pop->event_r_back[i] = ev;
+	}
+	poll_check_ok(pop);
+
+	return (0);
+}
+
+/*
+ * Nothing to be done here.
+ */
+
+static int
+poll_del(void *arg, struct event *ev)
+{
+	struct pollop *pop = arg;
+	struct pollfd *pfd = NULL;
+	int i;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_del(ev));
+
+	if (!(ev->ev_events & (EV_READ|EV_WRITE)))
+		return (0);
+
+	poll_check_ok(pop);
+	i = pop->idxplus1_by_fd[ev->ev_fd] - 1;
+	if (i < 0)
+		return (-1);
+
+	/* Do we still want to read or write? */
+	pfd = &pop->event_set[i];
+	if (ev->ev_events & EV_READ) {
+		pfd->events &= ~POLLIN;
+		pop->event_r_back[i] = NULL;
+	}
+	if (ev->ev_events & EV_WRITE) {
+		pfd->events &= ~POLLOUT;
+		pop->event_w_back[i] = NULL;
+	}
+	poll_check_ok(pop);
+	if (pfd->events)
+		/* Another event cares about that fd. */
+		return (0);
+
+	/* Okay, so we aren't interested in that fd anymore. */
+	pop->idxplus1_by_fd[ev->ev_fd] = 0;
+
+	--pop->nfds;
+	if (i != pop->nfds) {
+		/* 
+		 * Shift the last pollfd down into the now-unoccupied
+		 * position.
+		 */
+		memcpy(&pop->event_set[i], &pop->event_set[pop->nfds],
+		       sizeof(struct pollfd));
+		pop->event_r_back[i] = pop->event_r_back[pop->nfds];
+		pop->event_w_back[i] = pop->event_w_back[pop->nfds];
+		pop->idxplus1_by_fd[pop->event_set[i].fd] = i + 1;
+	}
+
+	poll_check_ok(pop);
+	return (0);
+}
+
+static void
+poll_dealloc(struct event_base *base, void *arg)
+{
+	struct pollop *pop = arg;
+
+	evsignal_dealloc(base);
+	if (pop->event_set)
+		free(pop->event_set);
+	if (pop->event_r_back)
+		free(pop->event_r_back);
+	if (pop->event_w_back)
+		free(pop->event_w_back);
+	if (pop->idxplus1_by_fd)
+		free(pop->idxplus1_by_fd);
+
+	memset(pop, 0, sizeof(struct pollop));
+	free(pop);
+}
diff --git a/libevent/select.c b/libevent/select.c
new file mode 100644
index 0000000..7faafe4
--- /dev/null
+++ b/libevent/select.c
@@ -0,0 +1,352 @@
+/*	$OpenBSD: select.c,v 1.2 2002/06/25 15:50:15 mickey Exp $	*/
+
+/*
+ * Copyright 2000-2002 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#else
+#include <sys/_time.h>
+#endif
+#ifdef HAVE_SYS_SELECT_H
+#include <sys/select.h>
+#endif
+#include <sys/queue.h>
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <errno.h>
+#ifdef CHECK_INVARIANTS
+#include <assert.h>
+#endif
+
+#include "event.h"
+#include "event-internal.h"
+#include "evsignal.h"
+#include "log.h"
+
+#ifndef howmany
+#define        howmany(x, y)   (((x)+((y)-1))/(y))
+#endif
+
+struct selectop {
+	int event_fds;		/* Highest fd in fd set */
+	int event_fdsz;
+	fd_set *event_readset_in;
+	fd_set *event_writeset_in;
+	fd_set *event_readset_out;
+	fd_set *event_writeset_out;
+	struct event **event_r_by_fd;
+	struct event **event_w_by_fd;
+};
+
+static void *select_init	(struct event_base *);
+static int select_add		(void *, struct event *);
+static int select_del		(void *, struct event *);
+static int select_dispatch	(struct event_base *, void *, struct timeval *);
+static void select_dealloc     (struct event_base *, void *);
+
+const struct eventop selectops = {
+	"select",
+	select_init,
+	select_add,
+	select_del,
+	select_dispatch,
+	select_dealloc,
+	0
+};
+
+static int select_resize(struct selectop *sop, int fdsz);
+
+static void *
+select_init(struct event_base *base)
+{
+	struct selectop *sop;
+
+	/* Disable select when this environment variable is set */
+	if (getenv("EVENT_NOSELECT"))
+		return (NULL);
+
+	if (!(sop = calloc(1, sizeof(struct selectop))))
+		return (NULL);
+
+	select_resize(sop, howmany(32 + 1, NFDBITS)*sizeof(fd_mask));
+
+	evsignal_init(base);
+
+	return (sop);
+}
+
+#ifdef CHECK_INVARIANTS
+static void
+check_selectop(struct selectop *sop)
+{
+	int i;
+	for (i = 0; i <= sop->event_fds; ++i) {
+		if (FD_ISSET(i, sop->event_readset_in)) {
+			assert(sop->event_r_by_fd[i]);
+			assert(sop->event_r_by_fd[i]->ev_events & EV_READ);
+			assert(sop->event_r_by_fd[i]->ev_fd == i);
+		} else {
+			assert(! sop->event_r_by_fd[i]);
+		}
+		if (FD_ISSET(i, sop->event_writeset_in)) {
+			assert(sop->event_w_by_fd[i]);
+			assert(sop->event_w_by_fd[i]->ev_events & EV_WRITE);
+			assert(sop->event_w_by_fd[i]->ev_fd == i);
+		} else {
+			assert(! sop->event_w_by_fd[i]);
+		}
+	}
+
+}
+#else
+#define check_selectop(sop) do { (void) sop; } while (0)
+#endif
+
+static int
+select_dispatch(struct event_base *base, void *arg, struct timeval *tv)
+{
+	int res, i;
+	struct selectop *sop = arg;
+
+	check_selectop(sop);
+
+	memcpy(sop->event_readset_out, sop->event_readset_in,
+	       sop->event_fdsz);
+	memcpy(sop->event_writeset_out, sop->event_writeset_in,
+	       sop->event_fdsz);
+
+	res = select(sop->event_fds + 1, sop->event_readset_out,
+	    sop->event_writeset_out, NULL, tv);
+
+	check_selectop(sop);
+
+	if (res == -1) {
+		if (errno != EINTR) {
+			event_warn("select");
+			return (-1);
+		}
+
+		evsignal_process(base);
+		return (0);
+	} else if (base->sig.evsignal_caught) {
+		evsignal_process(base);
+	}
+
+	event_debug(("%s: select reports %d", __func__, res));
+
+	check_selectop(sop);
+	for (i = 0; i <= sop->event_fds; ++i) {
+		struct event *r_ev = NULL, *w_ev = NULL;
+		res = 0;
+		if (FD_ISSET(i, sop->event_readset_out)) {
+			r_ev = sop->event_r_by_fd[i];
+			res |= EV_READ;
+		}
+		if (FD_ISSET(i, sop->event_writeset_out)) {
+			w_ev = sop->event_w_by_fd[i];
+			res |= EV_WRITE;
+		}
+		if (r_ev && (res & r_ev->ev_events)) {
+			event_active(r_ev, res & r_ev->ev_events, 1);
+		}
+		if (w_ev && w_ev != r_ev && (res & w_ev->ev_events)) {
+			event_active(w_ev, res & w_ev->ev_events, 1);
+		}
+	}
+	check_selectop(sop);
+
+	return (0);
+}
+
+
+static int
+select_resize(struct selectop *sop, int fdsz)
+{
+	int n_events, n_events_old;
+
+	fd_set *readset_in = NULL;
+	fd_set *writeset_in = NULL;
+	fd_set *readset_out = NULL;
+	fd_set *writeset_out = NULL;
+	struct event **r_by_fd = NULL;
+	struct event **w_by_fd = NULL;
+
+	n_events = (fdsz/sizeof(fd_mask)) * NFDBITS;
+	n_events_old = (sop->event_fdsz/sizeof(fd_mask)) * NFDBITS;
+
+	if (sop->event_readset_in)
+		check_selectop(sop);
+
+	if ((readset_in = realloc(sop->event_readset_in, fdsz)) == NULL)
+		goto error;
+	sop->event_readset_in = readset_in;
+	if ((readset_out = realloc(sop->event_readset_out, fdsz)) == NULL)
+		goto error;
+	sop->event_readset_out = readset_out;
+	if ((writeset_in = realloc(sop->event_writeset_in, fdsz)) == NULL)
+		goto error;
+	sop->event_writeset_in = writeset_in;
+	if ((writeset_out = realloc(sop->event_writeset_out, fdsz)) == NULL)
+		goto error;
+	sop->event_writeset_out = writeset_out;
+	if ((r_by_fd = realloc(sop->event_r_by_fd,
+		 n_events*sizeof(struct event*))) == NULL)
+		goto error;
+	sop->event_r_by_fd = r_by_fd;
+	if ((w_by_fd = realloc(sop->event_w_by_fd,
+		 n_events * sizeof(struct event*))) == NULL)
+		goto error;
+	sop->event_w_by_fd = w_by_fd;
+
+	memset((char *)sop->event_readset_in + sop->event_fdsz, 0,
+	    fdsz - sop->event_fdsz);
+	memset((char *)sop->event_writeset_in + sop->event_fdsz, 0,
+	    fdsz - sop->event_fdsz);
+	memset(sop->event_r_by_fd + n_events_old, 0,
+	    (n_events-n_events_old) * sizeof(struct event*));
+	memset(sop->event_w_by_fd + n_events_old, 0,
+	    (n_events-n_events_old) * sizeof(struct event*));
+
+	sop->event_fdsz = fdsz;
+	check_selectop(sop);
+
+	return (0);
+
+ error:
+	event_warn("malloc");
+	return (-1);
+}
+
+
+static int
+select_add(void *arg, struct event *ev)
+{
+	struct selectop *sop = arg;
+
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_add(ev));
+
+	check_selectop(sop);
+	/*
+	 * Keep track of the highest fd, so that we can calculate the size
+	 * of the fd_sets for select(2)
+	 */
+	if (sop->event_fds < ev->ev_fd) {
+		int fdsz = sop->event_fdsz;
+
+		if (fdsz < sizeof(fd_mask))
+			fdsz = sizeof(fd_mask);
+
+		while (fdsz <
+		    (howmany(ev->ev_fd + 1, NFDBITS) * sizeof(fd_mask)))
+			fdsz *= 2;
+
+		if (fdsz != sop->event_fdsz) {
+			if (select_resize(sop, fdsz)) {
+				check_selectop(sop);
+				return (-1);
+			}
+		}
+
+		sop->event_fds = ev->ev_fd;
+	}
+
+	if (ev->ev_events & EV_READ) {
+		FD_SET(ev->ev_fd, sop->event_readset_in);
+		sop->event_r_by_fd[ev->ev_fd] = ev;
+	}
+	if (ev->ev_events & EV_WRITE) {
+		FD_SET(ev->ev_fd, sop->event_writeset_in);
+		sop->event_w_by_fd[ev->ev_fd] = ev;
+	}
+	check_selectop(sop);
+
+	return (0);
+}
+
+/*
+ * Nothing to be done here.
+ */
+
+static int
+select_del(void *arg, struct event *ev)
+{
+	struct selectop *sop = arg;
+
+	check_selectop(sop);
+	if (ev->ev_events & EV_SIGNAL)
+		return (evsignal_del(ev));
+
+	if (sop->event_fds < ev->ev_fd) {
+		check_selectop(sop);
+		return (0);
+	}
+
+	if (ev->ev_events & EV_READ) {
+		FD_CLR(ev->ev_fd, sop->event_readset_in);
+		sop->event_r_by_fd[ev->ev_fd] = NULL;
+	}
+
+	if (ev->ev_events & EV_WRITE) {
+		FD_CLR(ev->ev_fd, sop->event_writeset_in);
+		sop->event_w_by_fd[ev->ev_fd] = NULL;
+	}
+
+	check_selectop(sop);
+	return (0);
+}
+
+static void
+select_dealloc(struct event_base *base, void *arg)
+{
+	struct selectop *sop = arg;
+
+	evsignal_dealloc(base);
+	if (sop->event_readset_in)
+		free(sop->event_readset_in);
+	if (sop->event_writeset_in)
+		free(sop->event_writeset_in);
+	if (sop->event_readset_out)
+		free(sop->event_readset_out);
+	if (sop->event_writeset_out)
+		free(sop->event_writeset_out);
+	if (sop->event_r_by_fd)
+		free(sop->event_r_by_fd);
+	if (sop->event_w_by_fd)
+		free(sop->event_w_by_fd);
+
+	memset(sop, 0, sizeof(struct selectop));
+	free(sop);
+}
diff --git a/libevent/signal.c b/libevent/signal.c
new file mode 100644
index 0000000..bcaa3f9
--- /dev/null
+++ b/libevent/signal.c
@@ -0,0 +1,347 @@
+/*	$OpenBSD: select.c,v 1.2 2002/06/25 15:50:15 mickey Exp $	*/
+
+/*
+ * Copyright 2000-2002 Niels Provos <provos@citi.umich.edu>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
+ * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
+ * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
+ * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
+ * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
+ * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
+ * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
+ * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
+ * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
+ * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif
+
+#ifdef WIN32
+#define WIN32_LEAN_AND_MEAN
+#include <winsock2.h>
+#include <windows.h>
+#undef WIN32_LEAN_AND_MEAN
+#endif
+#include <sys/types.h>
+#ifdef HAVE_SYS_TIME_H
+#include <sys/time.h>
+#endif
+#include <sys/queue.h>
+#ifdef HAVE_SYS_SOCKET_H
+#include <sys/socket.h>
+#endif
+#include <signal.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#ifdef HAVE_UNISTD_H
+#include <unistd.h>
+#endif
+#include <errno.h>
+#ifdef HAVE_FCNTL_H
+#include <fcntl.h>
+#endif
+#include <assert.h>
+
+#include "event.h"
+#include "event-internal.h"
+#include "evsignal.h"
+#include "evutil.h"
+#include "log.h"
+
+struct event_base *evsignal_base = NULL;
+
+static void evsignal_handler(int sig);
+
+/* Callback for when the signal handler write a byte to our signaling socket */
+static void
+evsignal_cb(int fd, short what, void *arg)
+{
+	static char signals[100];
+#ifdef WIN32
+	SSIZE_T n;
+#else
+	ssize_t n;
+#endif
+
+	n = recv(fd, signals, sizeof(signals), 0);
+	if (n == -1)
+		event_err(1, "%s: read", __func__);
+}
+
+#ifdef HAVE_SETFD
+#define FD_CLOSEONEXEC(x) do { \
+        if (fcntl(x, F_SETFD, 1) == -1) \
+                event_warn("fcntl(%d, F_SETFD)", x); \
+} while (0)
+#else
+#define FD_CLOSEONEXEC(x)
+#endif
+
+void
+evsignal_init(struct event_base *base)
+{
+	int i;
+
+	/* 
+	 * Our signal handler is going to write to one end of the socket
+	 * pair to wake up our event loop.  The event loop then scans for
+	 * signals that got delivered.
+	 */
+	if (evutil_socketpair(
+		    AF_UNIX, SOCK_STREAM, 0, base->sig.ev_signal_pair) == -1)
+		event_err(1, "%s: socketpair", __func__);
+
+	FD_CLOSEONEXEC(base->sig.ev_signal_pair[0]);
+	FD_CLOSEONEXEC(base->sig.ev_signal_pair[1]);
+	base->sig.sh_old = NULL;
+	base->sig.sh_old_max = 0;
+	base->sig.evsignal_caught = 0;
+	memset(&base->sig.evsigcaught, 0, sizeof(sig_atomic_t)*NSIG);
+	/* initialize the queues for all events */
+	for (i = 0; i < NSIG; ++i)
+		TAILQ_INIT(&base->sig.evsigevents[i]);
+
+        evutil_make_socket_nonblocking(base->sig.ev_signal_pair[0]);
+
+	event_set(&base->sig.ev_signal, base->sig.ev_signal_pair[1],
+		EV_READ | EV_PERSIST, evsignal_cb, &base->sig.ev_signal);
+	base->sig.ev_signal.ev_base = base;
+	base->sig.ev_signal.ev_flags |= EVLIST_INTERNAL;
+}
+
+/* Helper: set the signal handler for evsignal to handler in base, so that
+ * we can restore the original handler when we clear the current one. */
+int
+_evsignal_set_handler(struct event_base *base,
+		      int evsignal, void (*handler)(int))
+{
+#ifdef HAVE_SIGACTION
+	struct sigaction sa;
+#else
+	ev_sighandler_t sh;
+#endif
+	struct evsignal_info *sig = &base->sig;
+	void *p;
+
+	/*
+	 * resize saved signal handler array up to the highest signal number.
+	 * a dynamic array is used to keep footprint on the low side.
+	 */
+	if (evsignal >= sig->sh_old_max) {
+		int new_max = evsignal + 1;
+		event_debug(("%s: evsignal (%d) >= sh_old_max (%d), resizing",
+			    __func__, evsignal, sig->sh_old_max));
+		p = realloc(sig->sh_old, new_max * sizeof(*sig->sh_old));
+		if (p == NULL) {
+			event_warn("realloc");
+			return (-1);
+		}
+
+		memset((char *)p + sig->sh_old_max * sizeof(*sig->sh_old),
+		    0, (new_max - sig->sh_old_max) * sizeof(*sig->sh_old));
+
+		sig->sh_old_max = new_max;
+		sig->sh_old = p;
+	}
+
+	/* allocate space for previous handler out of dynamic array */
+	sig->sh_old[evsignal] = malloc(sizeof *sig->sh_old[evsignal]);
+	if (sig->sh_old[evsignal] == NULL) {
+		event_warn("malloc");
+		return (-1);
+	}
+
+	/* save previous handler and setup new handler */
+#ifdef HAVE_SIGACTION
+	memset(&sa, 0, sizeof(sa));
+	sa.sa_handler = handler;
+	sa.sa_flags |= SA_RESTART;
+	sigfillset(&sa.sa_mask);
+
+	if (sigaction(evsignal, &sa, sig->sh_old[evsignal]) == -1) {
+		event_warn("sigaction");
+		free(sig->sh_old[evsignal]);
+		return (-1);
+	}
+#else
+	if ((sh = signal(evsignal, handler)) == SIG_ERR) {
+		event_warn("signal");
+		free(sig->sh_old[evsignal]);
+		return (-1);
+	}
+	*sig->sh_old[evsignal] = sh;
+#endif
+
+	return (0);
+}
+
+int
+evsignal_add(struct event *ev)
+{
+	int evsignal;
+	struct event_base *base = ev->ev_base;
+	struct evsignal_info *sig = &ev->ev_base->sig;
+
+	if (ev->ev_events & (EV_READ|EV_WRITE))
+		event_errx(1, "%s: EV_SIGNAL incompatible use", __func__);
+	evsignal = EVENT_SIGNAL(ev);
+	assert(evsignal >= 0 && evsignal < NSIG);
+	if (TAILQ_EMPTY(&sig->evsigevents[evsignal])) {
+		event_debug(("%s: %p: changing signal handler", __func__, ev));
+		if (_evsignal_set_handler(
+			    base, evsignal, evsignal_handler) == -1)
+			return (-1);
+
+		/* catch signals if they happen quickly */
+		evsignal_base = base;
+
+		if (!sig->ev_signal_added) {
+			if (event_add(&sig->ev_signal, NULL))
+				return (-1);
+			sig->ev_signal_added = 1;
+		}
+	}
+
+	/* multiple events may listen to the same signal */
+	TAILQ_INSERT_TAIL(&sig->evsigevents[evsignal], ev, ev_signal_next);
+
+	return (0);
+}
+
+int
+_evsignal_restore_handler(struct event_base *base, int evsignal)
+{
+	int ret = 0;
+	struct evsignal_info *sig = &base->sig;
+#ifdef HAVE_SIGACTION
+	struct sigaction *sh;
+#else
+	ev_sighandler_t *sh;
+#endif
+
+	/* restore previous handler */
+	sh = sig->sh_old[evsignal];
+	sig->sh_old[evsignal] = NULL;
+#ifdef HAVE_SIGACTION
+	if (sigaction(evsignal, sh, NULL) == -1) {
+		event_warn("sigaction");
+		ret = -1;
+	}
+#else
+	if (signal(evsignal, *sh) == SIG_ERR) {
+		event_warn("signal");
+		ret = -1;
+	}
+#endif
+	free(sh);
+
+	return ret;
+}
+
+int
+evsignal_del(struct event *ev)
+{
+	struct event_base *base = ev->ev_base;
+	struct evsignal_info *sig = &base->sig;
+	int evsignal = EVENT_SIGNAL(ev);
+
+	assert(evsignal >= 0 && evsignal < NSIG);
+
+	/* multiple events may listen to the same signal */
+	TAILQ_REMOVE(&sig->evsigevents[evsignal], ev, ev_signal_next);
+
+	if (!TAILQ_EMPTY(&sig->evsigevents[evsignal]))
+		return (0);
+
+	event_debug(("%s: %p: restoring signal handler", __func__, ev));
+
+	return (_evsignal_restore_handler(ev->ev_base, EVENT_SIGNAL(ev)));
+}
+
+static void
+evsignal_handler(int sig)
+{
+	int save_errno = errno;
+
+	if (evsignal_base == NULL) {
+		event_warn(
+			"%s: received signal %d, but have no base configured",
+			__func__, sig);
+		return;
+	}
+
+	evsignal_base->sig.evsigcaught[sig]++;
+	evsignal_base->sig.evsignal_caught = 1;
+
+#ifndef HAVE_SIGACTION
+	signal(sig, evsignal_handler);
+#endif
+
+	/* Wake up our notification mechanism */
+	send(evsignal_base->sig.ev_signal_pair[0], "a", 1, 0);
+	errno = save_errno;
+}
+
+void
+evsignal_process(struct event_base *base)
+{
+	struct evsignal_info *sig = &base->sig;
+	struct event *ev, *next_ev;
+	sig_atomic_t ncalls;
+	int i;
+	
+	base->sig.evsignal_caught = 0;
+	for (i = 1; i < NSIG; ++i) {
+		ncalls = sig->evsigcaught[i];
+		if (ncalls == 0)
+			continue;
+
+		for (ev = TAILQ_FIRST(&sig->evsigevents[i]);
+		    ev != NULL; ev = next_ev) {
+			next_ev = TAILQ_NEXT(ev, ev_signal_next);
+			if (!(ev->ev_events & EV_PERSIST))
+				event_del(ev);
+			event_active(ev, EV_SIGNAL, ncalls);
+		}
+
+		sig->evsigcaught[i] = 0;
+	}
+}
+
+void
+evsignal_dealloc(struct event_base *base)
+{
+	int i = 0;
+	if (base->sig.ev_signal_added) {
+		event_del(&base->sig.ev_signal);
+		base->sig.ev_signal_added = 0;
+	}
+	for (i = 0; i < NSIG; ++i) {
+		if (i < base->sig.sh_old_max && base->sig.sh_old[i] != NULL)
+			_evsignal_restore_handler(base, i);
+	}
+
+	EVUTIL_CLOSESOCKET(base->sig.ev_signal_pair[0]);
+	base->sig.ev_signal_pair[0] = -1;
+	EVUTIL_CLOSESOCKET(base->sig.ev_signal_pair[1]);
+	base->sig.ev_signal_pair[1] = -1;
+	base->sig.sh_old_max = 0;
+
+	/* per index frees are handled in evsignal_del() */
+	free(base->sig.sh_old);
+}
diff --git a/libevent/strlcpy-internal.h b/libevent/strlcpy-internal.h
new file mode 100644
index 0000000..22b5f61
--- /dev/null
+++ b/libevent/strlcpy-internal.h
@@ -0,0 +1,23 @@
+#ifndef _STRLCPY_INTERNAL_H_
+#define _STRLCPY_INTERNAL_H_
+
+#ifdef __cplusplus
+extern "C" {
+#endif
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif /* HAVE_CONFIG_H */
+
+#ifndef HAVE_STRLCPY
+#include <string.h>
+size_t _event_strlcpy(char *dst, const char *src, size_t siz);
+#define strlcpy _event_strlcpy
+#endif
+
+#ifdef __cplusplus
+}
+#endif
+
+#endif
+
diff --git a/libevent/strlcpy.c b/libevent/strlcpy.c
new file mode 100644
index 0000000..a1a413d
--- /dev/null
+++ b/libevent/strlcpy.c
@@ -0,0 +1,78 @@
+/*	$OpenBSD: strlcpy.c,v 1.5 2001/05/13 15:40:16 deraadt Exp $	*/
+
+/*
+ * Copyright (c) 1998 Todd C. Miller <Todd.Miller@courtesan.com>
+ * All rights reserved.
+ *
+ * Redistribution and use in source and binary forms, with or without
+ * modification, are permitted provided that the following conditions
+ * are met:
+ * 1. Redistributions of source code must retain the above copyright
+ *    notice, this list of conditions and the following disclaimer.
+ * 2. Redistributions in binary form must reproduce the above copyright
+ *    notice, this list of conditions and the following disclaimer in the
+ *    documentation and/or other materials provided with the distribution.
+ * 3. The name of the author may not be used to endorse or promote products
+ *    derived from this software without specific prior written permission.
+ *
+ * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
+ * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
+ * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
+ * THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
+ * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
+ * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
+ * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
+ * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
+ * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
+ * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
+ */
+
+#if defined(LIBC_SCCS) && !defined(lint)
+static char *rcsid = "$OpenBSD: strlcpy.c,v 1.5 2001/05/13 15:40:16 deraadt Exp $";
+#endif /* LIBC_SCCS and not lint */
+
+#include "event-fpm.h"
+
+#include <sys/types.h>
+
+#ifdef HAVE_CONFIG_H
+#include "config.h"
+#endif /* HAVE_CONFIG_H */
+
+#ifndef HAVE_STRLCPY
+#include "strlcpy-internal.h"
+
+/*
+ * Copy src to string dst of size siz.  At most siz-1 characters
+ * will be copied.  Always NUL terminates (unless siz == 0).
+ * Returns strlen(src); if retval >= siz, truncation occurred.
+ */
+size_t
+_event_strlcpy(dst, src, siz)
+	char *dst;
+	const char *src;
+	size_t siz;
+{
+	register char *d = dst;
+	register const char *s = src;
+	register size_t n = siz;
+
+	/* Copy as many bytes as will fit */
+	if (n != 0 && --n != 0) {
+		do {
+			if ((*d++ = *s++) == 0)
+				break;
+		} while (--n != 0);
+	}
+
+	/* Not enough room in dst, add NUL and traverse rest of src */
+	if (n == 0) {
+		if (siz != 0)
+			*d = '\0';		/* NUL-terminate dst */
+		while (*s++)
+			;
+	}
+
+	return(s - src - 1);	/* count does not include NUL */
+}
+#endif
diff --git a/main/php_config.h.in b/main/php_config.h.in
index 6df7d68..f155934 100644
--- a/main/php_config.h.in
+++ b/main/php_config.h.in
@@ -170,6 +170,9 @@
 /* Define if you have the chroot function.  */
 #undef HAVE_CHROOT
 
+/* Define if you have the clearenv function.  */
+#undef HAVE_CLEARENV
+
 /* Define if you have the crypt function.  */
 #undef HAVE_CRYPT
 
@@ -935,6 +938,9 @@
 /*   */
 #undef PHP_FASTCGI
 
+/* Is experimental fastcgi process manager code activated */
+#undef PHP_FASTCGI_PM
+
 /*   */
 #undef FORCE_CGI_REDIRECT
 
@@ -944,6 +950,27 @@
 /*   */
 #undef ENABLE_PATHINFO_CHECK
 
+/* do we have libxml? */
+#undef HAVE_LIBXML
+
+/* do we have prctl? */
+#undef HAVE_PRCTL
+
+/* do we have clock_gettime? */
+#undef HAVE_CLOCK_GETTIME
+
+/* do we have clock_get_time? */
+#undef HAVE_CLOCK_GET_TIME
+
+/* do we have ptrace? */
+#undef HAVE_PTRACE
+
+/* do we have mach_vm_read? */
+#undef HAVE_MACH_VM_READ
+
+/* /proc/pid/mem interface */
+#undef PROC_MEM_FILE
+
 /* Define if system uses EBCDIC */
 #undef CHARSET_EBCDIC
 
diff --git a/sapi/cgi/Makefile.frag b/sapi/cgi/Makefile.frag
index 57a3b29..6fa6c9f 100644
--- a/sapi/cgi/Makefile.frag
+++ b/sapi/cgi/Makefile.frag
@@ -1,2 +1,2 @@
-$(SAPI_CGI_PATH): $(PHP_GLOBAL_OBJS) $(PHP_SAPI_OBJS)
+$(SAPI_CGI_PATH): $(PHP_GLOBAL_OBJS) $(PHP_SAPI_OBJS) $(SAPI_EXTRA_DEPS)
 	$(BUILD_CGI)
diff --git a/sapi/cgi/cgi_main.c b/sapi/cgi/cgi_main.c
index a4a19c2..2c19083 100644
--- a/sapi/cgi/cgi_main.c
+++ b/sapi/cgi/cgi_main.c
@@ -55,6 +55,9 @@
 #if HAVE_SYS_WAIT_H
 #include <sys/wait.h>
 #endif
+#if HAVE_FCNTL_H
+#include <fcntl.h>
+#endif
 #include "zend.h"
 #include "zend_extensions.h"
 #include "php_ini.h"
@@ -83,6 +86,11 @@ int __riscosify_control = __RISCOSIFY_STRICT_UNIX_SPECS;
 #if PHP_FASTCGI
 #include "fastcgi.h"
 
+#if PHP_FASTCGI_PM
+#include "fpm/fpm.h"
+#include "fpm/fpm_request.h"
+#endif
+
 #ifndef PHP_WIN32
 /* XXX this will need to change later when threaded fastcgi is
    implemented.  shane */
@@ -115,8 +123,12 @@ static int parent_waiting = 0;
 static pid_t pgroup;
 #endif
 
+static int request_body_fd;
+
 #endif
 
+static char *sapi_cgibin_getenv(char *name, size_t name_len TSRMLS_DC);
+
 #define PHP_MODE_STANDARD	1
 #define PHP_MODE_HIGHLIGHT	2
 #define PHP_MODE_INDENT		3
@@ -146,6 +158,10 @@ static const opt_struct OPTIONS[] = {
 	{'w', 0, "strip"},
 	{'?', 0, "usage"},/* help alias (both '?' and 'usage') */
 	{'v', 0, "version"},
+#if PHP_FASTCGI_PM
+	{'x', 0, "fpm"},
+	{'y', 1, "fpm-config"},
+#endif
 	{'z', 1, "zend-extension"},
 #if PHP_FASTCGI
  	{'T', 1, "timing"},
@@ -170,6 +186,7 @@ typedef struct _php_cgi_globals_struct {
 	zend_bool impersonate;
 # endif
 #endif
+	char *error_header;
 } php_cgi_globals_struct;
 
 #ifdef ZTS
@@ -474,7 +491,28 @@ static int sapi_cgi_read_post(char *buffer, uint count_bytes TSRMLS_DC)
 #if PHP_FASTCGI
 		if (fcgi_is_fastcgi()) {
 			fcgi_request *request = (fcgi_request*) SG(server_context);
-			tmp_read_bytes = fcgi_read(request, buffer + read_bytes, count_bytes - read_bytes);
+
+			if (request_body_fd == -1) {
+				char *request_body_filename = sapi_cgibin_getenv((char *) "REQUEST_BODY_FILE",
+						sizeof("REQUEST_BODY_FILE")-1 TSRMLS_CC);
+
+				if (request_body_filename && *request_body_filename) {
+					request_body_fd = open(request_body_filename, O_RDONLY);
+
+					if (0 > request_body_fd) {
+						php_error(E_WARNING, "REQUEST_BODY_FILE: open('%s') failed: %s (%d)",
+								request_body_filename, strerror(errno), errno);
+						return 0;
+					}
+				}
+			}
+
+			/* If REQUEST_BODY_FILE variable not available - read post body from fastcgi stream */
+			if (request_body_fd < 0) {
+				tmp_read_bytes = fcgi_read(request, buffer + read_bytes, count_bytes - read_bytes);
+			} else {
+				tmp_read_bytes = read(request_body_fd, buffer + read_bytes, count_bytes - read_bytes);
+			}
 		} else {
 			tmp_read_bytes = read(STDIN_FILENO, buffer + read_bytes, count_bytes - read_bytes);
 		}
@@ -786,7 +824,12 @@ static void php_cgi_usage(char *argv0)
 			   "  -s               Display colour syntax highlighted source.\n"
 			   "  -v               Version number\n"
 			   "  -w               Display source with stripped comments and whitespace.\n"
-			   "  -z <file>        Load Zend extension <file>.\n"
+#if PHP_FASTCGI_PM
+			   "  -x, --fpm        Run in FastCGI process manager mode.\n"
+			   "  -y, --fpm-config <file>\n"
+			   "                   Specify alternative path to FastCGI process manager config file.\n"
+#endif
+ 			   "  -z <file>        Load Zend extension <file>.\n"
 #if PHP_FASTCGI
 			   "  -T <count>       Measure execution time of script repeated <count> times.\n"
 #endif
@@ -1236,6 +1279,7 @@ PHP_INI_BEGIN()
 # ifdef PHP_WIN32
 	STD_PHP_INI_ENTRY("fastcgi.impersonate",     "0",  PHP_INI_SYSTEM, OnUpdateBool,   impersonate, php_cgi_globals_struct, php_cgi_globals)
 # endif
+	STD_PHP_INI_ENTRY("fastcgi.error_header",    NULL, PHP_INI_SYSTEM, OnUpdateString, error_header, php_cgi_globals_struct, php_cgi_globals)
 #endif
 PHP_INI_END()
 
@@ -1258,6 +1302,7 @@ static void php_cgi_globals_ctor(php_cgi_globals_struct *php_cgi_globals TSRMLS_
 # ifdef PHP_WIN32
 	php_cgi_globals->impersonate = 0;
 # endif
+	php_cgi_globals->error_header = NULL;
 #endif
 }
 /* }}} */
@@ -1290,9 +1335,47 @@ static PHP_MSHUTDOWN_FUNCTION(cgi)
 static PHP_MINFO_FUNCTION(cgi)
 {
 	DISPLAY_INI_ENTRIES();
+
+#if PHP_FASTCGI_PM
+
+#include "fpm/fpm_autoconf.h"
+
+	php_info_print_table_start();
+	php_info_print_table_row(2, "php-fpm", fpm ? "active" : "inactive");
+	php_info_print_table_row(2, "php-fpm version", PHP_FPM_VERSION);
+	php_info_print_table_end();
+#endif
+
 }
 /* }}} */
 
+#if PHP_FASTCGI
+PHP_FUNCTION(fastcgi_finish_request)
+{
+	fcgi_request *request = (fcgi_request*) SG(server_context);
+
+	if (fcgi_is_fastcgi() && request->fd >= 0) {
+
+		php_end_ob_buffers(1 TSRMLS_CC);
+		php_header(TSRMLS_C);
+
+		fcgi_flush(request, 1);
+		fcgi_close(request, 0, 0);
+		RETURN_TRUE;
+	}
+
+	RETURN_FALSE;
+
+}
+#endif
+
+function_entry cgi_fcgi_sapi_functions[] = {
+#if PHP_FASTCGI
+	PHP_FE(fastcgi_finish_request,				NULL)
+#endif
+	{NULL, NULL, NULL}
+};
+
 static zend_module_entry cgi_module_entry = {
 	STANDARD_MODULE_HEADER,
 #if PHP_FASTCGI
@@ -1300,7 +1383,7 @@ static zend_module_entry cgi_module_entry = {
 #else
 	"cgi",
 #endif
-	NULL, 
+	cgi_fcgi_sapi_functions, 
 	PHP_MINIT(cgi), 
 	PHP_MSHUTDOWN(cgi), 
 	NULL, 
@@ -1340,6 +1423,7 @@ int main(int argc, char *argv[])
 	char *bindpath = NULL;
 	int fcgi_fd = 0;
 	fcgi_request request;
+	char *fpm_config = NULL;
 	int repeats = 1;
 	int benchmark = 0;
 #if HAVE_GETTIMEOFDAY
@@ -1460,6 +1544,14 @@ int main(int argc, char *argv[])
 			case 's': /* generate highlighted HTML from source */
 				behavior = PHP_MODE_HIGHLIGHT;
 				break;
+#if PHP_FASTCGI_PM
+			case 'y':
+				fpm_config = php_optarg;
+				break;
+			case 'x':
+				fpm = 1;
+				break;
+#endif
 
 		}
 
@@ -1524,6 +1616,19 @@ consult the installation file that came with this distribution, or visit \n\
 #endif	/* FORCE_CGI_REDIRECT */
 
 #if PHP_FASTCGI
+#if PHP_FASTCGI_PM
+	if (fpm) {
+		if (0 > fpm_init(argc, argv, fpm_config)) {
+			return FAILURE;
+		}
+
+		fcgi_fd = fpm_run(&max_requests);
+
+		fcgi_set_is_fastcgi(fastcgi = 1);
+	}
+	else
+#endif
+
 	if (bindpath) {
 		fcgi_fd = fcgi_listen(bindpath, 128);
 		if (fcgi_fd < 0) {
@@ -1538,6 +1643,9 @@ consult the installation file that came with this distribution, or visit \n\
 	
 	if (fastcgi) {
 		/* How many times to run PHP scripts before dying */
+#if PHP_FASTCGI_PM
+		if (!fpm)
+#endif
 		if (getenv("PHP_FCGI_MAX_REQUESTS")) {
 			max_requests = atoi(getenv("PHP_FCGI_MAX_REQUESTS"));
 			if (max_requests < 0) {
@@ -1555,6 +1663,9 @@ consult the installation file that came with this distribution, or visit \n\
 
 #ifndef PHP_WIN32
 	/* Pre-fork, if required */
+#if PHP_FASTCGI_PM
+	if (!fpm)
+#endif
 	if (getenv("PHP_FCGI_CHILDREN")) {
 		char * children_str = getenv("PHP_FCGI_CHILDREN");
 		children = atoi(children_str);
@@ -1704,6 +1815,8 @@ consult the installation file that came with this distribution, or visit \n\
 #endif
 
 #if PHP_FASTCGI
+		request_body_fd = -1;
+
 		SG(server_context) = (void *) &request;
 #else
 		SG(server_context) = (void *) 1; /* avoid server_context==NULL checks */
@@ -1711,6 +1824,10 @@ consult the installation file that came with this distribution, or visit \n\
 		init_request_info(TSRMLS_C);
 		CG(interactive) = 0;
 
+#if PHP_FASTCGI_PM
+		if (fpm) fpm_request_info();
+#endif
+
 		if (!cgi
 #if PHP_FASTCGI
 			&& !fastcgi
@@ -1994,6 +2111,10 @@ consult the installation file that came with this distribution, or visit \n\
 			}
 		}
 
+#if PHP_FASTCGI_PM
+		if (fpm) fpm_request_executing();
+#endif
+
 		switch (behavior) {
 			case PHP_MODE_STANDARD:
 				php_execute_script(&file_handle TSRMLS_CC);
@@ -2046,6 +2167,10 @@ consult the installation file that came with this distribution, or visit \n\
 
 #if PHP_FASTCGI
 fastcgi_request_done:
+
+		if (request_body_fd != -1) close(request_body_fd);
+
+		request_body_fd = -2;
 #endif
 		{
 			char *path_translated;
@@ -2059,6 +2184,16 @@ fastcgi_request_done:
 				SG(request_info).path_translated = path_translated;
 			}
 
+			if (EG(exit_status) == 255) {
+				if (CGIG(error_header) && *CGIG(error_header)) {
+					sapi_header_line ctr = {0};
+
+					ctr.line = CGIG(error_header);
+					ctr.line_len = strlen(CGIG(error_header));
+					sapi_header_op(SAPI_HEADER_REPLACE, &ctr TSRMLS_CC);
+				}
+			}
+			
 			php_request_shutdown((void *) 0);
 			if (exit_status == 0) {
 				exit_status = EG(exit_status);
@@ -2096,15 +2231,20 @@ fastcgi_request_done:
 				if (bindpath) {
 					free(bindpath);
 				}
-				if (max_requests != 1) {
-					/* no need to return exit_status of the last request */
-					exit_status = 0;
-				}
 				break;
 			}
 			/* end of fastcgi loop */
 		}
 		fcgi_shutdown();
+
+		if (fcgi_in_shutdown() || 								/* graceful shutdown by a signal */
+				(max_requests && (requests == max_requests))	/* we were told to process max_requests and we are done */
+			) {
+			exit_status = 0;
+		}
+		else {
+			exit_status = 255;
+		}
 #endif
 
 		if (cgi_sapi_module.php_ini_path_override) {
diff --git a/sapi/cgi/config9.m4 b/sapi/cgi/config9.m4
index 4ff90fd..fdf409b 100644
--- a/sapi/cgi/config9.m4
+++ b/sapi/cgi/config9.m4
@@ -22,6 +22,10 @@ PHP_ARG_ENABLE(path-info-check,,
 [  --disable-path-info-check CGI: If this is disabled, paths such as
                             /info.php/test?a=b will fail to work], yes, no)
 
+PHP_ARG_ENABLE(fpm,,
+[  --enable-fpm              FastCGI: If this is enabled, the fastcgi support
+                            will include experimental process manager code], no, no)
+
 dnl
 dnl CGI setup
 dnl
@@ -54,6 +58,20 @@ if test "$PHP_SAPI" = "default"; then
     AC_DEFINE_UNQUOTED(PHP_FASTCGI, $PHP_ENABLE_FASTCGI, [ ])
     AC_MSG_RESULT($PHP_FASTCGI)
 
+    dnl --enable-fpm
+    if test "$PHP_FASTCGI" = "yes"; then
+      AC_MSG_CHECKING(whether to enable FastCGI Process Manager)
+      if test "$PHP_FPM" = "yes"; then
+        PHP_FASTCGI_PM=1
+      else
+        PHP_FASTCGI_PM=0
+      fi
+      AC_MSG_RESULT($PHP_FPM)
+    else
+      PHP_FASTCGI_PM=0
+    fi
+    AC_DEFINE_UNQUOTED(PHP_FASTCGI_PM, $PHP_FASTCGI_PM, [Is experimental fastcgi process manager code activated])
+
     dnl --enable-force-cgi-redirect
     AC_MSG_CHECKING(whether to force Apache CGI redirect)
     if test "$PHP_FORCE_CGI_REDIRECT" = "yes"; then
@@ -93,10 +111,10 @@ if test "$PHP_SAPI" = "default"; then
         BUILD_CGI="echo '\#! .' > php.sym && echo >>php.sym && nm -BCpg \`echo \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) | sed 's/\([A-Za-z0-9_]*\)\.lo/\1.o/g'\` | \$(AWK) '{ if (((\$\$2 == \"T\") || (\$\$2 == \"D\") || (\$\$2 == \"B\")) && (substr(\$\$3,1,1) != \".\")) { print \$\$3 } }' | sort -u >> php.sym && \$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) -Wl,-brtl -Wl,-bE:php.sym \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
         ;;
       *darwin*)
-        BUILD_CGI="\$(CC) \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(NATIVE_RPATHS) \$(PHP_GLOBAL_OBJS:.lo=.o) \$(PHP_SAPI_OBJS:.lo=.o) \$(PHP_FRAMEWORKS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
+        BUILD_CGI="\$(CC) \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(NATIVE_RPATHS) \$(PHP_GLOBAL_OBJS:.lo=.o) \$(PHP_SAPI_OBJS:.lo=.o) \$(PHP_FRAMEWORKS) \$(EXTRA_LIBS) \$(SAPI_EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
       ;;
       *)
-        BUILD_CGI="\$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
+        BUILD_CGI="\$(LIBTOOL) --mode=link \$(CC) -export-dynamic \$(CFLAGS_CLEAN) \$(EXTRA_CFLAGS) \$(EXTRA_LDFLAGS_PROGRAM) \$(LDFLAGS) \$(PHP_RPATHS) \$(PHP_GLOBAL_OBJS) \$(PHP_SAPI_OBJS) \$(EXTRA_LIBS) \$(SAPI_EXTRA_LIBS) \$(ZEND_EXTRA_LIBS) -o \$(SAPI_CGI_PATH)"
       ;;
     esac
 
diff --git a/sapi/cgi/fastcgi.c b/sapi/cgi/fastcgi.c
index 68b7e21..bcc0e7e 100644
--- a/sapi/cgi/fastcgi.c
+++ b/sapi/cgi/fastcgi.c
@@ -27,6 +27,11 @@
 #include <stdarg.h>
 #include <errno.h>
 
+#if PHP_FASTCGI_PM
+#include "fpm/fpm.h"
+#include "fpm/fpm_request.h"
+#endif
+
 #ifdef _WIN32
 
 #include <windows.h>
@@ -234,6 +239,8 @@ int fcgi_init(void)
 		} else {
 			return is_fastcgi = 0;
 		}
+
+		fcgi_set_allowed_clients(getenv("FCGI_WEB_SERVER_ADDRS"));
 #endif
 	}
 	return is_fastcgi;
@@ -249,14 +256,26 @@ int fcgi_is_fastcgi(void)
 	}
 }
 
+void fcgi_set_is_fastcgi(int new_value)
+{
+	is_fastcgi = new_value;
+}
+
+void fcgi_set_in_shutdown(int new_value)
+{
+	in_shutdown = new_value;
+}
+
 void fcgi_shutdown(void)
 {
 	if (is_initialized) {
 		zend_hash_destroy(&fcgi_mgmt_vars);
 	}
 	is_fastcgi = 0;
+
 	if (allowed_clients) {
 		free(allowed_clients);
+		allowed_clients = 0;
 	}
 }
 
@@ -330,6 +349,41 @@ out_fail:
 }
 #endif
 
+void fcgi_set_allowed_clients(char *ip)
+{
+    char *cur, *end;
+    int n;
+	    
+    if (ip) {
+    	ip = strdup(ip);
+    	cur = ip;
+    	n = 0;
+    	while (*cur) {
+    		if (*cur == ',') n++;
+    		cur++;
+    	}
+		if (allowed_clients) free(allowed_clients);
+    	allowed_clients = malloc(sizeof(in_addr_t) * (n+2));
+    	n = 0;
+    	cur = ip;
+    	while (cur) {
+	    	end = strchr(cur, ',');
+	    	if (end) {
+    			*end = 0;
+    			end++;
+    		}
+    		allowed_clients[n] = inet_addr(cur);
+    		if (allowed_clients[n] == INADDR_NONE) {
+				fprintf(stderr, "Wrong IP address '%s' in FCGI_WEB_SERVER_ADDRS\n", cur);
+    		}
+    		n++;
+    		cur = end;
+    	}
+    	allowed_clients[n] = INADDR_NONE;
+		free(ip);
+	}
+}
+
 static int is_port_number(const char *bindpath)
 {
 	while (*bindpath) {
@@ -458,38 +512,6 @@ int fcgi_listen(const char *path, int backlog)
 
 	if (!tcp) {
 		chmod(path, 0777);
-	} else {
-			char *ip = getenv("FCGI_WEB_SERVER_ADDRS");
-			char *cur, *end;
-			int n;
-			
-			if (ip) {
-				ip = strdup(ip);
-				cur = ip;
-				n = 0;
-				while (*cur) {
-					if (*cur == ',') n++;
-					cur++;
-				}
-				allowed_clients = malloc(sizeof(in_addr_t) * (n+2));
-				n = 0;
-				cur = ip;
-				while (cur) {
-					end = strchr(cur, ',');
-					if (end) {
-						*end = 0;
-						end++;
-					}
-					allowed_clients[n] = inet_addr(cur);
-					if (allowed_clients[n] == INADDR_NONE) {
-					fprintf(stderr, "Wrong IP address '%s' in FCGI_WEB_SERVER_ADDRS\n", cur);
-					}
-					n++;
-					cur = end;
-				}
-				allowed_clients[n] = INADDR_NONE;
-			free(ip);
-		}
 	}
 
 	if (!is_initialized) {
@@ -866,7 +888,7 @@ int fcgi_read(fcgi_request *req, char *str, int len)
 	return n;
 }
 
-static inline void fcgi_close(fcgi_request *req, int force, int destroy)
+void fcgi_close(fcgi_request *req, int force, int destroy)
 {
 	if (destroy) {
 		zend_hash_destroy(&req->env);
@@ -906,6 +928,10 @@ static inline void fcgi_close(fcgi_request *req, int force, int destroy)
 		close(req->fd);
 #endif
 		req->fd = -1;
+
+#if PHP_FASTCGI_PM
+		if (fpm) fpm_request_finished();
+#endif
 	}
 }
 
@@ -953,6 +979,10 @@ int fcgi_accept_request(fcgi_request *req)
 					sa_t sa;
 					socklen_t len = sizeof(sa);
 
+#if PHP_FASTCGI_PM
+					if (fpm) fpm_request_accepting();
+#endif
+
 					FCGI_LOCK(req->listen_socket);
 					req->fd = accept(listen_socket, (struct sockaddr *)&sa, &len);
 					FCGI_UNLOCK(req->listen_socket);
@@ -988,6 +1018,11 @@ int fcgi_accept_request(fcgi_request *req)
 				break;
 #else
 				if (req->fd >= 0) {
+
+#if PHP_FASTCGI_PM
+					if (fpm) fpm_request_reading_headers();
+#endif
+
 #if defined(HAVE_SYS_POLL_H) && defined(HAVE_POLL)
 					struct pollfd fds;
 					int ret;
diff --git a/sapi/cgi/fastcgi.h b/sapi/cgi/fastcgi.h
index c095c49..a3b3832 100644
--- a/sapi/cgi/fastcgi.h
+++ b/sapi/cgi/fastcgi.h
@@ -114,6 +114,9 @@ typedef struct _fcgi_request {
 int fcgi_init(void);
 void fcgi_shutdown(void);
 int fcgi_is_fastcgi(void);
+void fcgi_set_is_fastcgi(int);
+void fcgi_set_in_shutdown(int);
+void fcgi_set_allowed_clients(char *);
 int fcgi_in_shutdown(void);
 int fcgi_listen(const char *path, int backlog);
 void fcgi_init_request(fcgi_request *req, int listen_socket);
@@ -128,6 +131,8 @@ int fcgi_read(fcgi_request *req, char *str, int len);
 int fcgi_write(fcgi_request *req, fcgi_request_type type, const char *str, int len);
 int fcgi_flush(fcgi_request *req, int close);
 
+void fcgi_close(fcgi_request *req, int force, int destroy);
+
 #ifdef PHP_WIN32
 void fcgi_impersonate(void);
 #endif
diff --git a/sapi/cgi/fpm/Makefile.frag b/sapi/cgi/fpm/Makefile.frag
new file mode 100644
index 0000000..15e6637
--- /dev/null
+++ b/sapi/cgi/fpm/Makefile.frag
@@ -0,0 +1,21 @@
+
+install-fpm: sapi/cgi/fpm/php-fpm.conf sapi/cgi/fpm/php-fpm
+	@echo "Installing FPM config:            $(INSTALL_ROOT)$(php_fpm_conf_path)"
+	-@$(mkinstalldirs) \
+		$(INSTALL_ROOT)$(prefix)/sbin \
+		`dirname "$(INSTALL_ROOT)$(php_fpm_conf_path)"` \
+		`dirname "$(INSTALL_ROOT)$(php_fpm_log_path)"` \
+		`dirname "$(INSTALL_ROOT)$(php_fpm_pid_path)"`
+	-@if test -r "$(INSTALL_ROOT)$(php_fpm_conf_path)" ; then \
+		dest=`basename "$(php_fpm_conf_path)"`.default ; \
+		echo "                                  (installing as $$dest)" ; \
+	else \
+		dest=`basename "$(php_fpm_conf_path)"` ; \
+	fi ; \
+	$(INSTALL_DATA) $(top_builddir)/sapi/cgi/fpm/php-fpm.conf $(INSTALL_ROOT)`dirname "$(php_fpm_conf_path)"`/$$dest
+	@echo "Installing init.d script:         $(INSTALL_ROOT)$(prefix)/sbin/php-fpm"
+	-@$(INSTALL) -m 0755 $(top_builddir)/sapi/cgi/fpm/php-fpm $(INSTALL_ROOT)$(prefix)/sbin/php-fpm
+
+$(top_builddir)/libevent/libevent.a: $(top_builddir)/libevent/Makefile
+	cd $(top_builddir)/libevent && $(MAKE) libevent.a
+
diff --git a/sapi/cgi/fpm/acinclude.m4 b/sapi/cgi/fpm/acinclude.m4
new file mode 100644
index 0000000..e4d1f3e
--- /dev/null
+++ b/sapi/cgi/fpm/acinclude.m4
@@ -0,0 +1,377 @@
+
+AC_DEFUN([AC_FPM_CHECK_FUNC],
+[
+	SAVED_CFLAGS="$CFLAGS"
+	CFLAGS="$CFLAGS $2"
+	SAVED_LIBS="$LIBS"
+	LIBS="$LIBS $3"
+
+	AC_CHECK_FUNC([$1],[$4],[$5])
+
+	CFLAGS="$SAVED_CFLAGS"
+	LIBS="$SAVED_LIBS"
+])
+
+AC_DEFUN([AC_FPM_LIBEVENT],
+[
+	AC_ARG_WITH([libevent],
+	[  --with-libevent=DIR         FPM: libevent install directory])
+
+	LIBEVENT_CFLAGS=""
+	LIBEVENT_LIBS="-levent"
+	LIBEVENT_INCLUDE_PATH=""
+
+	if test "$with_libevent" != "no" -a -n "$with_libevent"; then
+		LIBEVENT_CFLAGS="-I$with_libevent/include"
+		LIBEVENT_LIBS="-L$with_libevent/lib $LIBEVENT_LIBS"
+		LIBEVENT_INCLUDE_PATH="$with_libevent/include"
+	fi
+
+	AC_MSG_CHECKING([for event.h])
+
+	found=no
+
+	for dir in "$LIBEVENT_INCLUDE_PATH" /usr/include ; do
+		if test -r "$dir/event.h" ; then
+			found=yes
+			break
+		fi
+	done
+
+	AC_MSG_RESULT([$found])
+
+	AC_FPM_CHECK_FUNC([event_set], [$LIBEVENT_CFLAGS], [$LIBEVENT_LIBS], ,
+		[AC_MSG_ERROR([Failed to link with libevent. Perhaps --with-libevent=DIR option could help.])])
+
+	AC_FPM_CHECK_FUNC([event_base_free], [$LIBEVENT_CFLAGS], [$LIBEVENT_LIBS], ,
+		[AC_MSG_ERROR([You have too old version. libevent version >= 1.2 is required.])])
+
+])
+
+AC_DEFUN([AC_FPM_LIBXML],
+[
+	AC_MSG_RESULT([checking for XML configuration])
+
+	AC_ARG_WITH(xml-config,
+	[  --with-xml-config=PATH      FPM: use xml-config in PATH to find libxml],
+		[XMLCONFIG="$withval"],
+		[AC_PATH_PROGS(XMLCONFIG, [xml2-config xml-config], "")]
+	)
+
+	if test "x$XMLCONFIG" = "x"; then
+		AC_MSG_ERROR([XML configuration could not be found])
+	else
+        AC_MSG_CHECKING([for libxml library])
+
+		if test ! -x "$XMLCONFIG"; then
+			AC_MSG_ERROR([$XMLCONFIG cannot be executed])
+		fi
+
+		LIBXML_LIBS="`$XMLCONFIG --libs`"
+		LIBXML_CFLAGS="`$XMLCONFIG --cflags`"
+		LIBXML_VERSION="`$XMLCONFIG --version`"
+
+        AC_MSG_RESULT([yes, $LIBXML_VERSION])
+
+		AC_FPM_CHECK_FUNC([xmlParseFile], [$LIBXML_CFLAGS], [$LIBXML_LIBS], ,
+			[AC_MSG_ERROR([Failed to link with libxml])])
+
+		AC_DEFINE(HAVE_LIBXML, 1, [do we have libxml?])
+	fi
+])
+
+AC_DEFUN([AC_FPM_JUDY],
+[
+	AC_ARG_WITH([Judy],
+	[  --with-Judy=DIR             FPM: Judy install directory])
+
+	JUDY_CFLAGS=""
+	JUDY_LIBS="-lJudy"
+	JUDY_INCLUDE_PATH=""
+
+	if test "$with_Judy" != "no" -a -n "$with_Judy"; then
+		JUDY_INCLUDE_PATH="$with_Judy/include"
+		JUDY_CFLAGS="-I$with_Judy/include $JUDY_CFLAGS"
+		JUDY_LIBS="-L$with_Judy/lib $JUDY_LIBS"
+	fi
+
+	AC_MSG_CHECKING([for Judy.h])
+
+	found=no
+
+	for dir in "$JUDY_INCLUDE_PATH" /usr/include ; do
+		if test -r "$dir/Judy.h" ; then
+			found=yes
+			break
+		fi
+	done
+
+	AC_MSG_RESULT([$found])
+
+	AC_FPM_CHECK_FUNC([JudyLCount], [$JUDY_CFLAGS], [$JUDY_LIBS], ,
+		[AC_MSG_ERROR([Failed to link with Judy])])
+
+])
+
+AC_DEFUN([AC_FPM_CLOCK],
+[
+	have_clock_gettime=no
+
+	AC_MSG_CHECKING([for clock_gettime])
+
+	AC_TRY_LINK([ #include <time.h> ], [struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);], [
+		have_clock_gettime=yes
+		AC_MSG_RESULT([yes])
+	], [
+		AC_MSG_RESULT([no])
+	])
+
+	if test "$have_clock_gettime" = "no"; then
+		AC_MSG_CHECKING([for clock_gettime in -lrt])
+
+		SAVED_LIBS="$LIBS"
+		LIBS="$LIBS -lrt"
+
+		AC_TRY_LINK([ #include <time.h> ], [struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);], [
+			have_clock_gettime=yes
+			AC_MSG_RESULT([yes])
+		], [
+			LIBS="$SAVED_LIBS"
+			AC_MSG_RESULT([no])
+		])
+	fi
+
+	if test "$have_clock_gettime" = "yes"; then
+		AC_DEFINE([HAVE_CLOCK_GETTIME], 1, [do we have clock_gettime?])
+	fi
+
+	have_clock_get_time=no
+
+	if test "$have_clock_gettime" = "no"; then
+		AC_MSG_CHECKING([for clock_get_time])
+
+		AC_TRY_RUN([ #include <mach/mach.h>
+			#include <mach/clock.h>
+			#include <mach/mach_error.h>
+
+			int main()
+			{
+				kern_return_t ret; clock_serv_t aClock; mach_timespec_t aTime;
+				ret = host_get_clock_service(mach_host_self(), REALTIME_CLOCK, &aClock);
+
+				if (ret != KERN_SUCCESS) {
+					return 1;
+				}
+
+				ret = clock_get_time(aClock, &aTime);
+				if (ret != KERN_SUCCESS) {
+					return 2;
+				}
+
+				return 0;
+			}
+		], [
+			have_clock_get_time=yes
+			AC_MSG_RESULT([yes])
+		], [
+			AC_MSG_RESULT([no])
+		])
+	fi
+
+	if test "$have_clock_get_time" = "yes"; then
+		AC_DEFINE([HAVE_CLOCK_GET_TIME], 1, [do we have clock_get_time?])
+	fi
+])
+
+AC_DEFUN([AC_FPM_TRACE],
+[
+	have_ptrace=no
+	have_broken_ptrace=no
+
+	AC_MSG_CHECKING([for ptrace])
+
+	AC_TRY_COMPILE([
+		#include <sys/types.h>
+		#include <sys/ptrace.h> ], [ptrace(0, 0, (void *) 0, 0);], [
+		have_ptrace=yes
+		AC_MSG_RESULT([yes])
+	], [
+		AC_MSG_RESULT([no])
+	])
+
+	if test "$have_ptrace" = "yes"; then
+		AC_MSG_CHECKING([whether ptrace works])
+
+		AC_TRY_RUN([
+			#include <unistd.h>
+			#include <signal.h>
+			#include <sys/wait.h>
+			#include <sys/types.h>
+			#include <sys/ptrace.h>
+			#include <errno.h>
+
+			#if !defined(PTRACE_ATTACH) && defined(PT_ATTACH)
+			#define PTRACE_ATTACH PT_ATTACH
+			#endif
+
+			#if !defined(PTRACE_DETACH) && defined(PT_DETACH)
+			#define PTRACE_DETACH PT_DETACH
+			#endif
+
+			#if !defined(PTRACE_PEEKDATA) && defined(PT_READ_D)
+			#define PTRACE_PEEKDATA PT_READ_D
+			#endif
+
+			int main()
+			{
+				long v1 = (unsigned int) -1; /* copy will fail if sizeof(long) == 8 and we've got "int ptrace()" */
+				long v2;
+				pid_t child;
+				int status;
+
+				if ( (child = fork()) ) { /* parent */
+					int ret = 0;
+
+					if (0 > ptrace(PTRACE_ATTACH, child, 0, 0)) {
+						return 1;
+					}
+
+					waitpid(child, &status, 0);
+
+			#ifdef PT_IO
+					struct ptrace_io_desc ptio = {
+						.piod_op = PIOD_READ_D,
+						.piod_offs = &v1,
+						.piod_addr = &v2,
+						.piod_len = sizeof(v1)
+					};
+
+					if (0 > ptrace(PT_IO, child, (void *) &ptio, 0)) {
+						ret = 1;
+					}
+			#else
+					errno = 0;
+
+					v2 = ptrace(PTRACE_PEEKDATA, child, (void *) &v1, 0);
+
+					if (errno) {
+						ret = 1;
+					}
+			#endif
+					ptrace(PTRACE_DETACH, child, (void *) 1, 0);
+
+					kill(child, SIGKILL);
+
+					return ret ? ret : (v1 != v2);
+				}
+				else { /* child */
+					sleep(10);
+					return 0;
+				}
+			}
+		], [
+			AC_MSG_RESULT([yes])
+		], [
+			have_ptrace=no
+			have_broken_ptrace=yes
+			AC_MSG_RESULT([no])
+		])
+	fi
+
+	if test "$have_ptrace" = "yes"; then
+		AC_DEFINE([HAVE_PTRACE], 1, [do we have ptrace?])
+	fi
+
+	have_mach_vm_read=no
+
+	if test "$have_broken_ptrace" = "yes"; then
+		AC_MSG_CHECKING([for mach_vm_read])
+
+		AC_TRY_COMPILE([ #include <mach/mach.h>
+			#include <mach/mach_vm.h>
+		], [
+			mach_vm_read((vm_map_t)0, (mach_vm_address_t)0, (mach_vm_size_t)0, (vm_offset_t *)0, (mach_msg_type_number_t*)0);
+		], [
+			have_mach_vm_read=yes
+			AC_MSG_RESULT([yes])
+		], [
+			AC_MSG_RESULT([no])
+		])
+	fi
+
+	if test "$have_mach_vm_read" = "yes"; then
+		AC_DEFINE([HAVE_MACH_VM_READ], 1, [do we have mach_vm_read?])
+	fi
+
+	proc_mem_file=""
+
+	if test -r /proc/$$/mem ; then
+		proc_mem_file="mem"
+	else
+		if test -r /proc/$$/as ; then
+			proc_mem_file="as"
+		fi
+	fi
+
+	if test -n "$proc_mem_file" ; then
+		AC_MSG_CHECKING([for proc mem file])
+
+		AC_TRY_RUN([
+			#define _GNU_SOURCE
+			#define _FILE_OFFSET_BITS 64
+			#include <stdint.h>
+			#include <unistd.h>
+			#include <sys/types.h>
+			#include <sys/stat.h>
+			#include <fcntl.h>
+			#include <stdio.h>
+			int main()
+			{
+				long v1 = (unsigned int) -1, v2 = 0;
+				char buf[128];
+				int fd;
+				sprintf(buf, "/proc/%d/$proc_mem_file", getpid());
+				fd = open(buf, O_RDONLY);
+				if (0 > fd) {
+					return 1;
+				}
+				if (sizeof(long) != pread(fd, &v2, sizeof(long), (uintptr_t) &v1)) {
+					close(fd);
+					return 1;
+				}
+				close(fd);
+				return v1 != v2;
+			}
+		], [
+			AC_MSG_RESULT([$proc_mem_file])
+		], [
+			proc_mem_file=""
+			AC_MSG_RESULT([no])
+		])
+	fi
+
+	if test -n "$proc_mem_file"; then
+		AC_DEFINE_UNQUOTED([PROC_MEM_FILE], "$proc_mem_file", [/proc/pid/mem interface])
+	fi
+
+	if test "$have_ptrace" = "yes"; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_ptrace.c"
+	elif test -n "$proc_mem_file"; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_pread.c"
+	elif test "$have_mach_vm_read" = "yes" ; then
+		FPM_SOURCES="$FPM_SOURCES fpm_trace.c fpm_trace_mach.c"
+	fi
+
+])
+
+AC_DEFUN([AC_FPM_PRCTL],
+[
+	AC_MSG_CHECKING([for prctl])
+
+	AC_TRY_COMPILE([ #include <sys/prctl.h> ], [prctl(0, 0, 0, 0, 0);], [
+		AC_DEFINE([HAVE_PRCTL], 1, [do we have prctl?])
+		AC_MSG_RESULT([yes])
+	], [
+		AC_MSG_RESULT([no])
+	])
+])
diff --git a/sapi/cgi/fpm/conf/php-fpm.conf.in b/sapi/cgi/fpm/conf/php-fpm.conf.in
new file mode 100644
index 0000000..a54b0c2
--- /dev/null
+++ b/sapi/cgi/fpm/conf/php-fpm.conf.in
@@ -0,0 +1,156 @@
+<?xml version="1.0" ?>
+<configuration>
+
+	All relative paths in this config are relative to php's install prefix
+
+	<section name="global_options">
+
+		Pid file
+		<value name="pid_file">@php_fpm_pid_path@</value>
+
+		Error log file
+		<value name="error_log">@php_fpm_log_path@</value>
+
+		Log level
+		<value name="log_level">notice</value>
+
+		When this amount of php processes exited with SIGSEGV or SIGBUS ...
+		<value name="emergency_restart_threshold">10</value>
+
+		... in a less than this interval of time, a graceful restart will be initiated.
+		Useful to work around accidental curruptions in accelerator's shared memory.
+		<value name="emergency_restart_interval">1m</value>
+
+		Time limit on waiting child's reaction on signals from master
+		<value name="process_control_timeout">5s</value>
+
+		Set to 'no' to debug fpm
+		<value name="daemonize">yes</value>
+
+	</section>
+
+	<workers>
+
+		<section name="pool">
+
+			Name of pool. Used in logs and stats.
+			<value name="name">default</value>
+
+			Address to accept fastcgi requests on.
+			Valid syntax is 'ip.ad.re.ss:port' or just 'port' or '/path/to/unix/socket'
+			<value name="listen_address">127.0.0.1:9000</value>
+
+			<value name="listen_options">
+
+				Set listen(2) backlog
+				<value name="backlog">-1</value>
+
+				Set permissions for unix socket, if one used.
+				In Linux read/write permissions must be set in order to allow connections from web server.
+				Many BSD-derrived systems allow connections regardless of permissions.
+				<value name="owner"></value>
+				<value name="group"></value>
+				<value name="mode">0666</value>
+			</value>
+
+			Additional php.ini defines, specific to this pool of workers.
+			<value name="php_defines">
+		<!--		<value name="sendmail_path">/usr/sbin/sendmail -t -i</value>		-->
+		<!--		<value name="display_errors">0</value>								-->
+			</value>
+
+			Unix user of processes
+		<!--	<value name="user">nobody</value>				-->
+
+			Unix group of processes
+		<!--	<value name="group">@php_fpm_group@</value>		-->
+
+			Process manager settings
+			<value name="pm">
+
+				Sets style of controling worker process count.
+				Valid values are 'static' and 'apache-like'
+				<value name="style">static</value>
+
+				Sets the limit on the number of simultaneous requests that will be served.
+				Equivalent to Apache MaxClients directive.
+				Equivalent to PHP_FCGI_CHILDREN environment in original php.fcgi
+				Used with any pm_style.
+				<value name="max_children">5</value>
+
+				Settings group for 'apache-like' pm style
+				<value name="apache_like">
+
+					Sets the number of server processes created on startup.
+					Used only when 'apache-like' pm_style is selected
+					<value name="StartServers">20</value>
+
+					Sets the desired minimum number of idle server processes.
+					Used only when 'apache-like' pm_style is selected
+					<value name="MinSpareServers">5</value>
+
+					Sets the desired maximum number of idle server processes.
+					Used only when 'apache-like' pm_style is selected
+					<value name="MaxSpareServers">35</value>
+
+				</value>
+
+			</value>
+
+			The timeout (in seconds) for serving a single request after which the worker process will be terminated
+			Should be used when 'max_execution_time' ini option does not stop script execution for some reason
+			'0s' means 'off'
+			<value name="request_terminate_timeout">0s</value>
+
+			The timeout (in seconds) for serving of single request after which a php backtrace will be dumped to slow.log file
+			'0s' means 'off'
+			<value name="request_slowlog_timeout">0s</value>
+
+			The log file for slow requests
+			<value name="slowlog">logs/slow.log</value>
+
+			Set open file desc rlimit
+			<value name="rlimit_files">1024</value>
+
+			Set max core size rlimit
+			<value name="rlimit_core">0</value>
+
+			Chroot to this directory at the start, absolute path
+			<value name="chroot"></value>
+
+			Chdir to this directory at the start, absolute path
+			<value name="chdir"></value>
+
+			Redirect workers' stdout and stderr into main error log.
+			If not set, they will be redirected to /dev/null, according to FastCGI specs
+			<value name="catch_workers_output">yes</value>
+
+			How much requests each process should execute before respawn.
+			Useful to work around memory leaks in 3rd party libraries.
+			For endless request processing please specify 0
+			Equivalent to PHP_FCGI_MAX_REQUESTS
+			<value name="max_requests">500</value>
+
+			Comma separated list of ipv4 addresses of FastCGI clients that allowed to connect.
+			Equivalent to FCGI_WEB_SERVER_ADDRS environment in original php.fcgi (5.2.2+)
+			Makes sense only with AF_INET listening socket.
+			<value name="allowed_clients">127.0.0.1</value>
+
+			Pass environment variables like LD_LIBRARY_PATH
+			All $VARIABLEs are taken from current environment
+			<value name="environment">
+				<value name="HOSTNAME">$HOSTNAME</value>
+				<value name="PATH">/usr/local/bin:/usr/bin:/bin</value>
+				<value name="TMP">/tmp</value>
+				<value name="TMPDIR">/tmp</value>
+				<value name="TEMP">/tmp</value>
+				<value name="OSTYPE">$OSTYPE</value>
+				<value name="MACHTYPE">$MACHTYPE</value>
+				<value name="MALLOC_CHECK_">2</value>
+			</value>
+
+		</section>
+
+	</workers>
+
+</configuration>
diff --git a/sapi/cgi/fpm/config.m4 b/sapi/cgi/fpm/config.m4
new file mode 100644
index 0000000..65ea5e2
--- /dev/null
+++ b/sapi/cgi/fpm/config.m4
@@ -0,0 +1,141 @@
+
+FPM_VERSION="0.5.14"
+
+PHP_ARG_WITH(fpm-conf, for php-fpm config file path,
+[  --with-fpm-conf=PATH        Set the path for php-fpm configuration file [PREFIX/etc/php-fpm.conf]], \$prefix/etc/php-fpm.conf, no)
+
+PHP_ARG_WITH(fpm-log, for php-fpm log file path,
+[  --with-fpm-log=PATH         Set the path for php-fpm log file [PREFIX/logs/php-fpm.log]], \$prefix/logs/php-fpm.log, no)
+
+PHP_ARG_WITH(fpm-pid, for php-fpm pid file path,
+[  --with-fpm-pid=PATH         Set the path for php-fpm pid file [PREFIX/logs/php-fpm.pid]], \$prefix/logs/php-fpm.pid, no)
+
+FPM_SOURCES="fpm.c \
+	fpm_conf.c \
+	fpm_signals.c \
+	fpm_children.c \
+	fpm_worker_pool.c \
+	fpm_unix.c \
+	fpm_cleanup.c \
+	fpm_sockets.c \
+	fpm_stdio.c \
+	fpm_env.c \
+	fpm_events.c \
+	fpm_php.c \
+	fpm_php_trace.c \
+	fpm_process_ctl.c \
+	fpm_request.c \
+	fpm_clock.c \
+	fpm_shm.c \
+	fpm_shm_slots.c \
+	xml_config.c \
+	zlog.c"
+
+dnl AC_FPM_LIBEVENT
+AC_FPM_LIBXML
+AC_FPM_PRCTL
+AC_FPM_CLOCK
+AC_FPM_TRACE
+dnl AC_FPM_JUDY
+
+LIBEVENT_CFLAGS="-I$abs_srcdir/libevent"
+LIBEVENT_LIBS="$abs_builddir/libevent/libevent.a"
+
+SAPI_EXTRA_DEPS="$LIBEVENT_LIBS"
+
+FPM_CFLAGS="$LIBEVENT_CFLAGS $LIBXML_CFLAGS $JUDY_CFLAGS"
+
+dnl FPM_CFLAGS="$FPM_CFLAGS -DJUDYERROR_NOTEST" # for Judy
+FPM_CFLAGS="$FPM_CFLAGS -I$abs_srcdir/sapi/cgi" # for fastcgi.h
+
+if test "$ICC" = "yes" ; then
+	FPM_ADD_CFLAGS="-Wall -wd279,310,869,810,981"
+elif test "$GCC" = "yes" ; then
+	FPM_ADD_CFLAGS="-Wall -Wpointer-arith -Wno-unused-parameter -Wunused-variable -Wunused-value -fno-strict-aliasing"
+fi
+
+if test -n "$FPM_WERROR" ; then
+	FPM_ADD_CFLAGS="$FPM_ADD_CFLAGS -Werror"
+fi
+
+FPM_CFLAGS="$FPM_ADD_CFLAGS $FPM_CFLAGS"
+
+PHP_ADD_MAKEFILE_FRAGMENT($abs_srcdir/sapi/cgi/fpm/Makefile.frag)
+
+PHP_ADD_SOURCES(sapi/cgi/fpm, $FPM_SOURCES, $FPM_CFLAGS, sapi)
+
+PHP_ADD_BUILD_DIR(sapi/cgi/fpm)
+
+install_fpm="install-fpm"
+
+PHP_CONFIGURE_PART(Configuring libevent)
+
+test -d "$abs_builddir/libevent" || mkdir -p $abs_builddir/libevent
+
+dnl this is a bad hack
+
+chmod +x "$abs_srcdir/libevent/configure" \
+		"$abs_srcdir/libevent/depcomp" \
+		"$abs_srcdir/libevent/install-sh" \
+		"$abs_srcdir/libevent/missing"
+
+libevent_configure="cd $abs_builddir/libevent ; CFLAGS=\"$CFLAGS $GCC_CFLAGS\" $abs_srcdir/libevent/configure --disable-shared"
+
+(eval $libevent_configure)
+
+if test ! -f "$abs_builddir/libevent/Makefile" ; then
+	echo "Failed to configure libevent" >&2
+	exit 1
+fi
+
+dnl another hack for stealing libevent dependant library list
+
+LIBEVENT_LIBS="$LIBEVENT_LIBS `echo "@LIBS@" | $abs_builddir/libevent/config.status --file=-:-`"
+
+SAPI_EXTRA_LIBS="$LIBEVENT_LIBS $LIBXML_LIBS $JUDY_LIBS"
+
+
+if test "$prefix" = "NONE" ; then
+	fpm_prefix=/usr/local
+else
+	fpm_prefix="$prefix"
+fi
+
+if test "$PHP_FPM_CONF" = "\$prefix/etc/php-fpm.conf" ; then
+	php_fpm_conf_path="$fpm_prefix/etc/php-fpm.conf"
+else
+	php_fpm_conf_path="$PHP_FPM_CONF"
+fi
+
+if test "$PHP_FPM_LOG" = "\$prefix/logs/php-fpm.log" ; then
+	php_fpm_log_path="$fpm_prefix/logs/php-fpm.log"
+else
+	php_fpm_log_path="$PHP_FPM_LOG"
+fi
+
+if test "$PHP_FPM_PID" = "\$prefix/logs/php-fpm.pid" ; then
+	php_fpm_pid_path="$fpm_prefix/logs/php-fpm.pid"
+else
+	php_fpm_pid_path="$PHP_FPM_PID"
+fi
+
+
+if grep nobody /etc/group >/dev/null 2>&1; then
+	php_fpm_group=nobody
+else
+	if grep nogroup /etc/group >/dev/null 2>&1; then
+		php_fpm_group=nogroup
+	else
+		php_fpm_group=nobody
+	fi
+fi
+
+PHP_SUBST_OLD(php_fpm_conf_path)
+PHP_SUBST_OLD(php_fpm_log_path)
+PHP_SUBST_OLD(php_fpm_pid_path)
+PHP_SUBST_OLD(php_fpm_group)
+PHP_SUBST_OLD(FPM_VERSION)
+
+PHP_OUTPUT(sapi/cgi/fpm/fpm_autoconf.h)
+PHP_OUTPUT(sapi/cgi/fpm/php-fpm.conf:sapi/cgi/fpm/conf/php-fpm.conf.in)
+PHP_OUTPUT(sapi/cgi/fpm/php-fpm:sapi/cgi/fpm/init.d/php-fpm.in)
diff --git a/sapi/cgi/fpm/fpm.c b/sapi/cgi/fpm/fpm.c
new file mode 100644
index 0000000..9db2c9b
--- /dev/null
+++ b/sapi/cgi/fpm/fpm.c
@@ -0,0 +1,84 @@
+
+	/* $Id: fpm.c,v 1.23 2008/07/20 16:38:31 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <stdlib.h> /* for exit */
+
+#include "fpm.h"
+#include "fpm_children.h"
+#include "fpm_signals.h"
+#include "fpm_env.h"
+#include "fpm_events.h"
+#include "fpm_cleanup.h"
+#include "fpm_php.h"
+#include "fpm_sockets.h"
+#include "fpm_unix.h"
+#include "fpm_process_ctl.h"
+#include "fpm_conf.h"
+#include "fpm_worker_pool.h"
+#include "fpm_stdio.h"
+#include "zlog.h"
+
+int fpm;
+
+struct fpm_globals_s fpm_globals;
+
+int fpm_init(int argc, char **argv, char *config)
+{
+	fpm_globals.argc = argc;
+	fpm_globals.argv = argv;
+	fpm_globals.config = config;
+
+	if (0 > fpm_php_init_main()              ||
+		0 > fpm_stdio_init_main()            ||
+		0 > fpm_conf_init_main()             ||
+		0 > fpm_unix_init_main()             ||
+		0 > fpm_env_init_main()              ||
+		0 > fpm_signals_init_main()          ||
+		0 > fpm_pctl_init_main()             ||
+		0 > fpm_children_init_main()         ||
+		0 > fpm_sockets_init_main()          ||
+		0 > fpm_worker_pool_init_main()      ||
+		0 > fpm_event_init_main()) {
+		return -1;
+	}
+
+	if (0 > fpm_conf_write_pid()) {
+		return -1;
+	}
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "fpm is running, pid %d", (int) fpm_globals.parent_pid);
+
+	return 0;
+}
+
+/*	children: return listening socket
+	parent: never return */
+int fpm_run(int *max_requests)
+{
+	struct fpm_worker_pool_s *wp;
+
+	/* create initial children in all pools */
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+		int is_parent;
+
+		is_parent = fpm_children_create_initial(wp);
+
+		if (!is_parent) {
+			goto run_child;
+		}
+	}
+
+	/* run event loop forever */
+	fpm_event_loop();
+
+run_child: /* only workers reach this point */
+
+	fpm_cleanups_run(FPM_CLEANUP_CHILD);
+
+	*max_requests = fpm_globals.max_requests;
+	return fpm_globals.listening_socket;
+}
+
diff --git a/sapi/cgi/fpm/fpm.h b/sapi/cgi/fpm/fpm.h
new file mode 100644
index 0000000..eebd2dc
--- /dev/null
+++ b/sapi/cgi/fpm/fpm.h
@@ -0,0 +1,30 @@
+
+	/* $Id: fpm.h,v 1.13 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_H
+#define FPM_H 1
+
+#include <unistd.h>
+
+int fpm_run(int *max_requests);
+int fpm_init(int argc, char **argv, char *config);
+
+struct fpm_globals_s {
+	pid_t parent_pid;
+	int argc;
+	char **argv;
+	char *config;
+	int running_children;
+	int error_log_fd;
+	int log_level;
+	int listening_socket; /* for this child */
+	int max_requests; /* for this child */
+	int is_child;
+};
+
+extern struct fpm_globals_s fpm_globals;
+
+extern int fpm;
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_arrays.h b/sapi/cgi/fpm/fpm_arrays.h
new file mode 100644
index 0000000..fee6661
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_arrays.h
@@ -0,0 +1,110 @@
+
+	/* $Id: fpm_arrays.h,v 1.2 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_ARRAYS_H
+#define FPM_ARRAYS_H 1
+
+#include <stdlib.h>
+#include <string.h>
+
+struct fpm_array_s {
+	void *data;
+	size_t sz;
+	size_t used;
+	size_t allocated;
+};
+
+static inline struct fpm_array_s *fpm_array_init(struct fpm_array_s *a, unsigned int sz, unsigned int initial_num)
+{
+	void *allocated = 0;
+
+	if (!a) {
+		a = malloc(sizeof(struct fpm_array_s));
+
+		if (!a) {
+			return 0;
+		}
+
+		allocated = a;
+	}
+
+	a->sz = sz;
+
+	a->data = calloc(sz, initial_num);
+
+	if (!a->data) {
+		free(allocated);
+		return 0;
+	}
+
+	a->allocated = initial_num;
+	a->used = 0;
+
+	return a;
+}
+
+static inline void *fpm_array_item(struct fpm_array_s *a, unsigned int n)
+{
+	char *ret;
+
+	ret = (char *) a->data + a->sz * n;
+
+	return ret;
+}
+
+static inline void *fpm_array_item_last(struct fpm_array_s *a)
+{
+	return fpm_array_item(a, a->used - 1);
+}
+
+static inline int fpm_array_item_remove(struct fpm_array_s *a, unsigned int n)
+{
+	int ret = -1;
+
+	if (n < a->used - 1) {
+		void *last = fpm_array_item(a, a->used - 1);
+		void *to_remove = fpm_array_item(a, n);
+
+		memcpy(to_remove, last, a->sz);
+
+		ret = n;
+	}
+
+	--a->used;
+
+	return ret;
+}
+
+static inline void *fpm_array_push(struct fpm_array_s *a)
+{
+	void *ret;
+
+	if (a->used == a->allocated) {
+		size_t new_allocated = a->allocated ? a->allocated * 2 : 20;
+		void *new_ptr = realloc(a->data, a->sz * new_allocated);
+
+		if (!new_ptr) {
+			return 0;
+		}
+
+		a->data = new_ptr;
+		a->allocated = new_allocated;
+	}
+
+	ret = fpm_array_item(a, a->used);
+
+	++a->used;
+
+	return ret;
+}
+
+static inline void fpm_array_free(struct fpm_array_s *a)
+{
+	free(a->data);
+	a->data = 0;
+	a->sz = 0;
+	a->used = a->allocated = 0;
+}
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_atomic.h b/sapi/cgi/fpm/fpm_atomic.h
new file mode 100644
index 0000000..3334ae0
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_atomic.h
@@ -0,0 +1,85 @@
+
+	/* $Id: fpm_atomic.h,v 1.3 2008/09/18 23:34:11 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_ATOMIC_H
+#define FPM_ATOMIC_H 1
+
+#include <stdint.h>
+#include <sched.h>
+
+#if ( __i386__ || __i386 )
+
+typedef int32_t                     atomic_int_t;
+typedef uint32_t                    atomic_uint_t;
+typedef volatile atomic_uint_t      atomic_t;
+
+
+static inline atomic_int_t atomic_fetch_add(atomic_t *value, atomic_int_t add)
+{
+	__asm__ volatile ( "lock;" "xaddl %0, %1;" :
+		"+r" (add) : "m" (*value) : "memory");
+
+	return add;
+}
+
+static inline atomic_uint_t atomic_cmp_set(atomic_t *lock, atomic_uint_t old, atomic_uint_t set)
+{
+	unsigned char res;
+
+	__asm__ volatile ( "lock;" "cmpxchgl %3, %1;" "sete %0;" :
+		"=a" (res) : "m" (*lock), "a" (old), "r" (set) : "memory");
+
+    return res;
+}
+
+#elif ( __amd64__ || __amd64 )
+
+typedef int64_t                     atomic_int_t;
+typedef uint64_t                    atomic_uint_t;
+typedef volatile atomic_uint_t      atomic_t;
+
+static inline atomic_int_t atomic_fetch_add(atomic_t *value, atomic_int_t add)
+{
+	__asm__ volatile ( "lock;" "xaddq %0, %1;" :
+		"+r" (add) : "m" (*value) : "memory");
+
+	return add;
+}
+
+static inline atomic_uint_t atomic_cmp_set(atomic_t *lock, atomic_uint_t old, atomic_uint_t set)
+{
+	unsigned char res;
+
+	__asm__ volatile ( "lock;" "cmpxchgq %3, %1;" "sete %0;" :
+		"=a" (res) : "m" (*lock), "a" (old), "r" (set) : "memory");
+
+	return res;
+}
+
+#else
+
+#error unsupported processor. please write a patch and send it to me
+
+#endif
+
+static inline int fpm_spinlock(atomic_t *lock, int try_once)
+{
+	if (try_once) {
+		return atomic_cmp_set(lock, 0, 1) ? 0 : -1;
+	}
+
+	for (;;) {
+
+		if (atomic_cmp_set(lock, 0, 1)) {
+			break;
+		}
+
+		sched_yield();
+	}
+
+	return 0;
+}
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_autoconf.h.in b/sapi/cgi/fpm/fpm_autoconf.h.in
new file mode 100644
index 0000000..d00c165
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_autoconf.h.in
@@ -0,0 +1,9 @@
+
+	/* $Id: fpm_autoconf.h.in,v 1.3 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#define PHP_FPM_VERSION   "@FPM_VERSION@"
+#define PHP_FPM_CONF_PATH "@php_fpm_conf_path@"
+#define PHP_FPM_LOG_PATH  "@php_fpm_log_path@"
+#define PHP_FPM_PID_PATH  "@php_fpm_pid_path@"
+
diff --git a/sapi/cgi/fpm/fpm_children.c b/sapi/cgi/fpm/fpm_children.c
new file mode 100644
index 0000000..f586405
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_children.c
@@ -0,0 +1,385 @@
+
+	/* $Id: fpm_children.c,v 1.32.2.2 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/types.h>
+#include <sys/wait.h>
+#include <time.h>
+#include <unistd.h>
+#include <string.h>
+#include <stdio.h>
+
+#include "fpm.h"
+#include "fpm_children.h"
+#include "fpm_signals.h"
+#include "fpm_worker_pool.h"
+#include "fpm_sockets.h"
+#include "fpm_process_ctl.h"
+#include "fpm_php.h"
+#include "fpm_conf.h"
+#include "fpm_cleanup.h"
+#include "fpm_events.h"
+#include "fpm_clock.h"
+#include "fpm_stdio.h"
+#include "fpm_unix.h"
+#include "fpm_env.h"
+#include "fpm_shm_slots.h"
+
+#include "zlog.h"
+
+static time_t *last_faults;
+static int fault;
+
+static int fpm_children_make(struct fpm_worker_pool_s *wp, int in_event_loop);
+
+static void fpm_children_cleanup(int which, void *arg)
+{
+	free(last_faults);
+}
+
+static struct fpm_child_s *fpm_child_alloc()
+{
+	struct fpm_child_s *ret;
+
+	ret = malloc(sizeof(struct fpm_child_s));
+
+	if (!ret) return 0;
+
+	memset(ret, 0, sizeof(*ret));
+
+	return ret;
+}
+
+static void fpm_child_free(struct fpm_child_s *child)
+{
+	free(child);
+}
+
+static void fpm_child_close(struct fpm_child_s *child, int in_event_loop)
+{
+	if (child->fd_stdout != -1) {
+		if (in_event_loop) {
+			fpm_event_fire(&child->ev_stdout);
+		}
+		if (child->fd_stdout != -1) {
+			close(child->fd_stdout);
+		}
+	}
+
+	if (child->fd_stderr != -1) {
+		if (in_event_loop) {
+			fpm_event_fire(&child->ev_stderr);
+		}
+		if (child->fd_stderr != -1) {
+			close(child->fd_stderr);
+		}
+	}
+
+	fpm_child_free(child);
+}
+
+static void fpm_child_link(struct fpm_child_s *child)
+{
+	struct fpm_worker_pool_s *wp = child->wp;
+
+	++wp->running_children;
+	++fpm_globals.running_children;
+
+	child->next = wp->children;
+	if (child->next) child->next->prev = child;
+	child->prev = 0;
+	wp->children = child;
+}
+
+static void fpm_child_unlink(struct fpm_child_s *child)
+{
+	--child->wp->running_children;
+	--fpm_globals.running_children;
+
+	if (child->prev) child->prev->next = child->next;
+	else child->wp->children = child->next;
+	if (child->next) child->next->prev = child->prev;
+
+}
+
+static struct fpm_child_s *fpm_child_find(pid_t pid)
+{
+	struct fpm_worker_pool_s *wp;
+	struct fpm_child_s *child = 0;
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+
+		for (child = wp->children; child; child = child->next) {
+			if (child->pid == pid) {
+				break;
+			}
+		}
+
+		if (child) break;
+	}
+
+	if (!child) {
+		return 0;
+	}
+
+	return child;
+}
+
+static void fpm_child_init(struct fpm_worker_pool_s *wp)
+{
+	fpm_globals.max_requests = wp->config->max_requests;
+
+	if (0 > fpm_stdio_init_child(wp) ||
+		0 > fpm_unix_init_child(wp) ||
+		0 > fpm_signals_init_child() ||
+		0 > fpm_env_init_child(wp) ||
+		0 > fpm_php_init_child(wp)) {
+
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "child failed to initialize (pool %s)", wp->config->name);
+		exit(255);
+	}
+}
+
+int fpm_children_free(struct fpm_child_s *child)
+{
+	struct fpm_child_s *next;
+
+	for (; child; child = next) {
+		next = child->next;
+		fpm_child_close(child, 0 /* in_event_loop */);
+	}
+
+	return 0;
+}
+
+void fpm_children_bury()
+{
+	int status;
+	pid_t pid;
+	struct fpm_child_s *child;
+
+	while ( (pid = waitpid(-1, &status, WNOHANG | WUNTRACED)) > 0) {
+		char buf[128];
+		int severity = ZLOG_NOTICE;
+
+		child = fpm_child_find(pid);
+
+		if (WIFEXITED(status)) {
+
+			snprintf(buf, sizeof(buf), "with code %d", WEXITSTATUS(status));
+
+			if (WEXITSTATUS(status) != 0) {
+				severity = ZLOG_WARNING;
+			}
+
+		}
+		else if (WIFSIGNALED(status)) {
+			const char *signame = fpm_signal_names[WTERMSIG(status)];
+			const char *have_core = WCOREDUMP(status) ? " (core dumped)" : "";
+
+			if (signame == NULL) {
+				signame = "";
+			}
+
+			snprintf(buf, sizeof(buf), "on signal %d %s%s", WTERMSIG(status), signame, have_core);
+
+			if (WTERMSIG(status) != SIGQUIT) { /* possible request loss */
+				severity = ZLOG_WARNING;
+			}
+		}
+		else if (WIFSTOPPED(status)) {
+
+			zlog(ZLOG_STUFF, ZLOG_NOTICE, "child %d stopped for tracing", (int) pid);
+
+			if (child && child->tracer) {
+				child->tracer(child);
+			}
+
+			continue;
+		}
+
+		if (child) {
+			struct fpm_worker_pool_s *wp = child->wp;
+			struct timeval tv1, tv2;
+
+			fpm_child_unlink(child);
+
+			fpm_shm_slots_discard_slot(child);
+
+			fpm_clock_get(&tv1);
+
+			timersub(&tv1, &child->started, &tv2);
+
+			zlog(ZLOG_STUFF, severity, "child %d (pool %s) exited %s after %ld.%06d seconds from start", (int) pid,
+						child->wp->config->name, buf, tv2.tv_sec, (int) tv2.tv_usec);
+
+			fpm_child_close(child, 1 /* in event_loop */);
+
+			fpm_pctl_child_exited();
+
+			if (last_faults && (WTERMSIG(status) == SIGSEGV || WTERMSIG(status) == SIGBUS)) {
+				time_t now = tv1.tv_sec;
+				int restart_condition = 1;
+				int i;
+
+				last_faults[fault++] = now;
+
+				if (fault == fpm_global_config.emergency_restart_threshold) {
+					fault = 0;
+				}
+
+				for (i = 0; i < fpm_global_config.emergency_restart_threshold; i++) {
+					if (now - last_faults[i] > fpm_global_config.emergency_restart_interval) {
+						restart_condition = 0;
+						break;
+					}
+				}
+
+				if (restart_condition) {
+
+					zlog(ZLOG_STUFF, ZLOG_WARNING, "failed processes threshold (%d in %d sec) is reached, initiating reload",
+						fpm_global_config.emergency_restart_threshold, fpm_global_config.emergency_restart_interval);
+
+					fpm_pctl(FPM_PCTL_STATE_RELOADING, FPM_PCTL_ACTION_SET);
+				}
+			}
+
+			fpm_children_make(wp, 1 /* in event loop */);
+
+			if (fpm_globals.is_child) {
+				break;
+			}
+		}
+		else {
+			zlog(ZLOG_STUFF, ZLOG_ALERT, "oops, unknown child exited %s", buf);
+		}
+	}
+
+}
+
+static struct fpm_child_s *fpm_resources_prepare(struct fpm_worker_pool_s *wp)
+{
+	struct fpm_child_s *c;
+
+	c = fpm_child_alloc();
+
+	if (!c) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "malloc failed (pool %s)", wp->config->name);
+		return 0;
+	}
+
+	c->wp = wp;
+	c->fd_stdout = -1; c->fd_stderr = -1;
+
+	if (0 > fpm_stdio_prepare_pipes(c)) {
+		fpm_child_free(c);
+		return 0;
+	}
+
+	if (0 > fpm_shm_slots_prepare_slot(c)) {
+		fpm_stdio_discard_pipes(c);
+		fpm_child_free(c);
+		return 0;
+	}
+
+	return c;
+}
+
+static void fpm_resources_discard(struct fpm_child_s *child)
+{
+	fpm_shm_slots_discard_slot(child);
+	fpm_stdio_discard_pipes(child);
+	fpm_child_free(child);
+}
+
+static void fpm_child_resources_use(struct fpm_child_s *child)
+{
+	fpm_shm_slots_child_use_slot(child);
+	fpm_stdio_child_use_pipes(child);
+	fpm_child_free(child);
+}
+
+static void fpm_parent_resources_use(struct fpm_child_s *child)
+{
+	fpm_shm_slots_parent_use_slot(child);
+	fpm_stdio_parent_use_pipes(child);
+	fpm_child_link(child);
+}
+
+static int fpm_children_make(struct fpm_worker_pool_s *wp, int in_event_loop)
+{
+	int enough = 0;
+	pid_t pid;
+	struct fpm_child_s *child;
+
+	while (!enough && fpm_pctl_can_spawn_children() && wp->running_children < wp->config->pm->max_children) {
+
+		child = fpm_resources_prepare(wp);
+
+		if (!child) {
+			enough = 1;
+			break;
+		}
+
+		pid = fork();
+
+		switch (pid) {
+
+			case 0 :
+				fpm_child_resources_use(child);
+				fpm_globals.is_child = 1;
+				if (in_event_loop) {
+					fpm_event_exit_loop();
+				}
+				fpm_child_init(wp);
+				return 0;
+
+			case -1 :
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fork() failed");
+				enough = 1;
+
+				fpm_resources_discard(child);
+
+				break; /* dont try any more on error */
+
+			default :
+				child->pid = pid;
+				fpm_clock_get(&child->started);
+				fpm_parent_resources_use(child);
+
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "child %d (pool %s) started", (int) pid, wp->config->name);
+		}
+
+	}
+
+	return 1; /* we are done */
+}
+
+int fpm_children_create_initial(struct fpm_worker_pool_s *wp)
+{
+	return fpm_children_make(wp, 0 /* not in event loop yet */);
+}
+
+int fpm_children_init_main()
+{
+	if (fpm_global_config.emergency_restart_threshold &&
+		fpm_global_config.emergency_restart_interval) {
+
+		last_faults = malloc(sizeof(time_t) * fpm_global_config.emergency_restart_threshold);
+
+		if (!last_faults) {
+			return -1;
+		}
+
+		memset(last_faults, 0, sizeof(time_t) * fpm_global_config.emergency_restart_threshold);
+	}
+
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_children_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
+
diff --git a/sapi/cgi/fpm/fpm_children.h b/sapi/cgi/fpm/fpm_children.h
new file mode 100644
index 0000000..c85adf9
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_children.h
@@ -0,0 +1,33 @@
+
+	/* $Id: fpm_children.h,v 1.9 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_CHILDREN_H
+#define FPM_CHILDREN_H 1
+
+#include <sys/time.h>
+#include <sys/types.h>
+#include <event.h>
+
+#include "fpm_worker_pool.h"
+
+int fpm_children_create_initial(struct fpm_worker_pool_s *wp);
+int fpm_children_free(struct fpm_child_s *child);
+void fpm_children_bury();
+int fpm_children_init_main();
+
+struct fpm_child_s;
+
+struct fpm_child_s {
+	struct fpm_child_s *prev, *next;
+	struct timeval started;
+	struct fpm_worker_pool_s *wp;
+	struct event ev_stdout, ev_stderr;
+	int shm_slot_i;
+	int fd_stdout, fd_stderr;
+	void (*tracer)(struct fpm_child_s *);
+	struct timeval slow_logged;
+	pid_t pid;
+};
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_cleanup.c b/sapi/cgi/fpm/fpm_cleanup.c
new file mode 100644
index 0000000..b4ef7bb
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_cleanup.c
@@ -0,0 +1,51 @@
+
+	/* $Id: fpm_cleanup.c,v 1.8 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <stdlib.h>
+
+#include "fpm_arrays.h"
+#include "fpm_cleanup.h"
+#include "zlog.h"
+
+struct cleanup_s {
+	int type;
+	void (*cleanup)(int, void *);
+	void *arg;
+};
+
+static struct fpm_array_s cleanups = { .sz = sizeof(struct cleanup_s) };
+
+int fpm_cleanup_add(int type, void (*cleanup)(int, void *), void *arg)
+{
+	struct cleanup_s *c;
+
+	c = fpm_array_push(&cleanups);
+
+	if (!c) {
+		return -1;
+	}
+
+	c->type = type;
+	c->cleanup = cleanup;
+	c->arg = arg;
+
+	return 0;
+}
+
+void fpm_cleanups_run(int type)
+{
+	struct cleanup_s *c = fpm_array_item_last(&cleanups);
+	int cl = cleanups.used;
+
+	for ( ; cl--; c--) {
+		if (c->type & type) {
+			c->cleanup(type, c->arg);
+		}
+	}
+
+	fpm_array_free(&cleanups);
+}
+
diff --git a/sapi/cgi/fpm/fpm_cleanup.h b/sapi/cgi/fpm/fpm_cleanup.h
new file mode 100644
index 0000000..4d7cf39
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_cleanup.h
@@ -0,0 +1,21 @@
+
+	/* $Id: fpm_cleanup.h,v 1.5 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_CLEANUP_H
+#define FPM_CLEANUP_H 1
+
+int fpm_cleanup_add(int type, void (*cleanup)(int, void *), void *);
+void fpm_cleanups_run(int type);
+
+enum {
+	FPM_CLEANUP_CHILD					= (1 << 0),
+	FPM_CLEANUP_PARENT_EXIT				= (1 << 1),
+	FPM_CLEANUP_PARENT_EXIT_MAIN		= (1 << 2),
+	FPM_CLEANUP_PARENT_EXEC				= (1 << 3),
+	FPM_CLEANUP_PARENT					= (1 << 1) | (1 << 2) | (1 << 3),
+	FPM_CLEANUP_ALL						= ~0,
+};
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_clock.c b/sapi/cgi/fpm/fpm_clock.c
new file mode 100644
index 0000000..2abbce8
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_clock.c
@@ -0,0 +1,115 @@
+
+	/* $Id: fpm_clock.c,v 1.4 2008/09/18 23:19:59 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#if defined(HAVE_CLOCK_GETTIME)
+#include <time.h> /* for CLOCK_MONOTONIC */
+#endif
+
+#include "fpm_clock.h"
+#include "zlog.h"
+
+
+/* posix monotonic clock - preferred source of time */
+#if defined(HAVE_CLOCK_GETTIME) && defined(CLOCK_MONOTONIC)
+
+static int monotonic_works;
+
+int fpm_clock_init()
+{
+	struct timespec ts;
+
+	monotonic_works = 0;
+
+	if (0 == clock_gettime(CLOCK_MONOTONIC, &ts)) {
+		monotonic_works = 1;
+	}
+
+	return 0;
+}
+
+int fpm_clock_get(struct timeval *tv)
+{
+	if (monotonic_works) {
+		struct timespec ts;
+
+		if (0 > clock_gettime(CLOCK_MONOTONIC, &ts)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "clock_gettime() failed");
+			return -1;
+		}
+
+		tv->tv_sec = ts.tv_sec;
+		tv->tv_usec = ts.tv_nsec / 1000;
+		return 0;
+	}
+
+	return gettimeofday(tv, 0);
+}
+
+/* macosx clock */
+#elif defined(HAVE_CLOCK_GET_TIME)
+
+#include <mach/mach.h>
+#include <mach/clock.h>
+#include <mach/mach_error.h>
+
+static clock_serv_t mach_clock;
+
+/* this code borrowed from here: http://lists.apple.com/archives/Darwin-development/2002/Mar/msg00746.html */
+/* mach_clock also should be re-initialized in child process after fork */
+int fpm_clock_init()
+{
+	kern_return_t ret;
+	mach_timespec_t aTime;
+
+	ret = host_get_clock_service(mach_host_self(), REALTIME_CLOCK, &mach_clock);
+
+	if (ret != KERN_SUCCESS) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "host_get_clock_service() failed: %s", mach_error_string(ret));
+		return -1;
+	}
+
+	/* test if it works */
+	ret = clock_get_time(mach_clock, &aTime);
+
+	if (ret != KERN_SUCCESS) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "clock_get_time() failed: %s", mach_error_string(ret));
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_clock_get(struct timeval *tv)
+{
+	kern_return_t ret;
+	mach_timespec_t aTime;
+
+	ret = clock_get_time(mach_clock, &aTime);
+
+	if (ret != KERN_SUCCESS) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "clock_get_time() failed: %s", mach_error_string(ret));
+		return -1;
+	}
+
+	tv->tv_sec = aTime.tv_sec;
+	tv->tv_usec = aTime.tv_nsec / 1000;
+
+	return 0;
+}
+
+#else /* no clock */
+
+int fpm_clock_init()
+{
+	return 0;
+}
+
+int fpm_clock_get(struct timeval *tv)
+{
+	return gettimeofday(tv, 0);
+}
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_clock.h b/sapi/cgi/fpm/fpm_clock.h
new file mode 100644
index 0000000..6aab959
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_clock.h
@@ -0,0 +1,13 @@
+
+	/* $Id: fpm_clock.h,v 1.2 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_CLOCK_H
+#define FPM_CLOCK_H 1
+
+#include <sys/time.h>
+
+int fpm_clock_init();
+int fpm_clock_get(struct timeval *tv);
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_conf.c b/sapi/cgi/fpm/fpm_conf.c
new file mode 100644
index 0000000..adf4f1a
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_conf.c
@@ -0,0 +1,532 @@
+
+	/* $Id: fpm_conf.c,v 1.33.2.3 2008/12/13 03:50:29 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/types.h>
+#include <sys/stat.h>
+#include <fcntl.h>
+#include <string.h>
+#include <stdlib.h>
+#include <stddef.h>
+#include <stdint.h>
+#include <stdio.h>
+#include <unistd.h>
+
+#include "fpm.h"
+#include "fpm_conf.h"
+#include "fpm_stdio.h"
+#include "fpm_worker_pool.h"
+#include "fpm_cleanup.h"
+#include "fpm_php.h"
+#include "fpm_sockets.h"
+#include "xml_config.h"
+#include "zlog.h"
+
+
+struct fpm_global_config_s fpm_global_config;
+
+static void *fpm_global_config_ptr()
+{
+	return &fpm_global_config;
+}
+
+static char *fpm_conf_set_log_level(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+
+	if (!strcmp(value, "debug")) {
+		fpm_globals.log_level = ZLOG_DEBUG;
+	}
+	else if (!strcmp(value, "notice")) {
+		fpm_globals.log_level = ZLOG_NOTICE;
+	}
+	else if (!strcmp(value, "warn")) {
+		fpm_globals.log_level = ZLOG_WARNING;
+	}
+	else if (!strcmp(value, "error")) {
+		fpm_globals.log_level = ZLOG_ERROR;
+	}
+	else if (!strcmp(value, "alert")) {
+		fpm_globals.log_level = ZLOG_ALERT;
+	}
+	else {
+		return "invalid value for 'log_level'";
+	}
+
+	return NULL;
+}
+
+static struct xml_conf_section xml_section_fpm_global_options = {
+	.conf = &fpm_global_config_ptr,
+	.path = "/configuration/global_options",
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR,	"emergency_restart_threshold",		&xml_conf_set_slot_integer,		offsetof(struct fpm_global_config_s, emergency_restart_threshold) },
+		{ XML_CONF_SCALAR,	"emergency_restart_interval",		&xml_conf_set_slot_time,		offsetof(struct fpm_global_config_s, emergency_restart_interval) },
+		{ XML_CONF_SCALAR,	"process_control_timeout",			&xml_conf_set_slot_time,		offsetof(struct fpm_global_config_s, process_control_timeout) },
+		{ XML_CONF_SCALAR,	"daemonize",						&xml_conf_set_slot_boolean,		offsetof(struct fpm_global_config_s, daemonize) },
+		{ XML_CONF_SCALAR,	"pid_file",							&xml_conf_set_slot_string,		offsetof(struct fpm_global_config_s, pid_file) },
+		{ XML_CONF_SCALAR,	"error_log",						&xml_conf_set_slot_string,		offsetof(struct fpm_global_config_s, error_log) },
+		{ XML_CONF_SCALAR,  "log_level",						&fpm_conf_set_log_level,		0 },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static char *fpm_conf_set_pm_style(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	struct fpm_pm_s *c = *conf;
+
+	if (!strcmp(value, "static")) {
+		c->style = PM_STYLE_STATIC;
+	}
+	else if (!strcmp(value, "apache-like")) {
+		c->style = PM_STYLE_APACHE_LIKE;
+	}
+	else {
+		return "invalid value for 'style'";
+	}
+
+	return NULL;
+}
+
+static char *fpm_conf_set_rlimit_core(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	struct fpm_worker_pool_config_s *c = *conf;
+
+	if (!strcmp(value, "unlimited")) {
+		c->rlimit_core = -1;
+	}
+	else {
+		int int_value;
+		void *subconf = &int_value;
+		char *error;
+
+		error = xml_conf_set_slot_integer(&subconf, name, vv, 0);
+
+		if (error) return error;
+
+		if (int_value < 0) return "invalid value for 'rlimit_core'";
+
+		c->rlimit_core = int_value;
+	}
+
+	return NULL;
+}
+
+static char *fpm_conf_set_catch_workers_output(void **conf, char *name, void *vv, intptr_t offset)
+{
+	struct fpm_worker_pool_config_s *c = *conf;
+	int int_value;
+	void *subconf = &int_value;
+	char *error;
+
+	error = xml_conf_set_slot_boolean(&subconf, name, vv, 0);
+
+	if (error) return error;
+
+	c->catch_workers_output = int_value;
+
+	return NULL;
+}
+
+static struct xml_conf_section fpm_conf_set_apache_like_subsection_conf = {
+	.path = "apache_like somewhere", /* fixme */
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR, "StartServers",		&xml_conf_set_slot_integer, offsetof(struct fpm_pm_s, options_apache_like.StartServers) },
+		{ XML_CONF_SCALAR, "MinSpareServers",	&xml_conf_set_slot_integer, offsetof(struct fpm_pm_s, options_apache_like.MinSpareServers) },
+		{ XML_CONF_SCALAR, "MaxSpareServers",	&xml_conf_set_slot_integer, offsetof(struct fpm_pm_s, options_apache_like.MaxSpareServers) },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static char *fpm_conf_set_apache_like_subsection(void **conf, char *name, void *xml_node, intptr_t offset)
+{
+	return xml_conf_parse_section(conf, &fpm_conf_set_apache_like_subsection_conf, xml_node);
+}
+
+static struct xml_conf_section fpm_conf_set_listen_options_subsection_conf = {
+	.path = "listen options somewhere", /* fixme */
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR,		"backlog",		&xml_conf_set_slot_integer,		offsetof(struct fpm_listen_options_s, backlog) },
+		{ XML_CONF_SCALAR,		"owner",		&xml_conf_set_slot_string,		offsetof(struct fpm_listen_options_s, owner) },
+		{ XML_CONF_SCALAR,		"group",		&xml_conf_set_slot_string,		offsetof(struct fpm_listen_options_s, group) },
+		{ XML_CONF_SCALAR,		"mode",			&xml_conf_set_slot_string,		offsetof(struct fpm_listen_options_s, mode) },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static char *fpm_conf_set_listen_options_subsection(void **conf, char *name, void *xml_node, intptr_t offset)
+{
+	void *subconf = (char *) *conf + offset;
+	struct fpm_listen_options_s *lo;
+
+	lo = malloc(sizeof(*lo));
+
+	if (!lo) {
+		return "malloc() failed";
+	}
+
+	memset(lo, 0, sizeof(*lo));
+
+	lo->backlog = -1;
+
+	* (struct fpm_listen_options_s **) subconf = lo;
+
+	subconf = lo;
+
+	return xml_conf_parse_section(&subconf, &fpm_conf_set_listen_options_subsection_conf, xml_node);
+}
+
+static struct xml_conf_section fpm_conf_set_pm_subsection_conf = {
+	.path = "pm settings somewhere", /* fixme */
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR,		"style",				&fpm_conf_set_pm_style,						0 },
+		{ XML_CONF_SCALAR,		"max_children",			&xml_conf_set_slot_integer,					offsetof(struct fpm_pm_s, max_children) },
+		{ XML_CONF_SUBSECTION,	"apache_like",			&fpm_conf_set_apache_like_subsection,		offsetof(struct fpm_pm_s, options_apache_like) },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static char *fpm_conf_set_pm_subsection(void **conf, char *name, void *xml_node, intptr_t offset)
+{
+	void *subconf = (char *) *conf + offset;
+	struct fpm_pm_s *pm;
+
+	pm = malloc(sizeof(*pm));
+
+	if (!pm) {
+		return "fpm_conf_set_pm_subsection(): malloc failed";
+	}
+
+	memset(pm, 0, sizeof(*pm));
+
+	* (struct fpm_pm_s **) subconf = pm;
+
+	subconf = pm;
+
+	return xml_conf_parse_section(&subconf, &fpm_conf_set_pm_subsection_conf, xml_node);
+}
+
+static char *xml_conf_set_slot_key_value_pair(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	struct key_value_s *kv;
+	struct key_value_s ***parent = (struct key_value_s ***) conf;
+
+	kv = malloc(sizeof(*kv));
+
+	if (!kv) {
+		return "malloc() failed";
+	}
+
+	memset(kv, 0, sizeof(*kv));
+
+	kv->key = strdup(name);
+	kv->value = strdup(value);
+
+	if (!kv->key || !kv->value) {
+		return "xml_conf_set_slot_key_value_pair(): strdup() failed";
+	}
+
+	**parent = kv;
+
+	*parent = &kv->next;
+
+	return NULL;
+}
+
+static struct xml_conf_section fpm_conf_set_key_value_pairs_subsection_conf = {
+	.path = "key_value_pairs somewhere", /* fixme */
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR, 0, &xml_conf_set_slot_key_value_pair, 0 },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static char *fpm_conf_set_key_value_pairs_subsection(void **conf, char *name, void *xml_node, intptr_t offset)
+{
+	void *next_kv = (char *) *conf + offset;
+
+	return xml_conf_parse_section(&next_kv, &fpm_conf_set_key_value_pairs_subsection_conf, xml_node);
+}
+
+static void *fpm_worker_pool_config_alloc()
+{
+	static struct fpm_worker_pool_s *current_wp = 0;
+	struct fpm_worker_pool_s *wp;
+
+	wp = fpm_worker_pool_alloc();
+
+	if (!wp) return 0;
+
+	wp->config = malloc(sizeof(struct fpm_worker_pool_config_s));
+
+	if (!wp->config) return 0;
+
+	memset(wp->config, 0, sizeof(struct fpm_worker_pool_config_s));
+
+	if (current_wp) current_wp->next = wp;
+
+	current_wp = wp;
+
+	return wp->config;
+}
+
+int fpm_worker_pool_config_free(struct fpm_worker_pool_config_s *wpc)
+{
+	struct key_value_s *kv, *kv_next;
+
+	free(wpc->name);
+	free(wpc->listen_address);
+	if (wpc->listen_options) {
+		free(wpc->listen_options->owner);
+		free(wpc->listen_options->group);
+		free(wpc->listen_options->mode);
+		free(wpc->listen_options);
+	}
+	for (kv = wpc->php_defines; kv; kv = kv_next) {
+		kv_next = kv->next;
+		free(kv->key);
+		free(kv->value);
+		free(kv);
+	}
+	for (kv = wpc->environment; kv; kv = kv_next) {
+		kv_next = kv->next;
+		free(kv->key);
+		free(kv->value);
+		free(kv);
+	}
+	free(wpc->pm);
+	free(wpc->user);
+	free(wpc->group);
+	free(wpc->chroot);
+	free(wpc->chdir);
+	free(wpc->allowed_clients);
+	free(wpc->slowlog);
+
+	return 0;
+}
+
+static struct xml_conf_section xml_section_fpm_worker_pool_config = {
+	.conf = &fpm_worker_pool_config_alloc,
+	.path = "/configuration/workers/pool",
+	.parsers = (struct xml_value_parser []) {
+		{ XML_CONF_SCALAR,		"name",							&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, name) },
+		{ XML_CONF_SCALAR,		"listen_address",				&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, listen_address) },
+		{ XML_CONF_SUBSECTION,	"listen_options",				&fpm_conf_set_listen_options_subsection,	offsetof(struct fpm_worker_pool_config_s, listen_options) },
+		{ XML_CONF_SUBSECTION,	"php_defines",					&fpm_conf_set_key_value_pairs_subsection,	offsetof(struct fpm_worker_pool_config_s, php_defines) },
+		{ XML_CONF_SCALAR,		"user",							&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, user) },
+		{ XML_CONF_SCALAR,		"group",						&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, group) },
+		{ XML_CONF_SCALAR,		"chroot",						&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, chroot) },
+		{ XML_CONF_SCALAR,		"chdir",						&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, chdir) },
+		{ XML_CONF_SCALAR,		"allowed_clients",				&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, allowed_clients) },
+		{ XML_CONF_SUBSECTION,	"environment",					&fpm_conf_set_key_value_pairs_subsection,	offsetof(struct fpm_worker_pool_config_s, environment) },
+		{ XML_CONF_SCALAR,		"request_terminate_timeout",	&xml_conf_set_slot_time,					offsetof(struct fpm_worker_pool_config_s, request_terminate_timeout) },
+		{ XML_CONF_SCALAR,		"request_slowlog_timeout",		&xml_conf_set_slot_time,					offsetof(struct fpm_worker_pool_config_s, request_slowlog_timeout) },
+		{ XML_CONF_SCALAR,		"slowlog",						&xml_conf_set_slot_string,					offsetof(struct fpm_worker_pool_config_s, slowlog) },
+		{ XML_CONF_SCALAR,		"rlimit_files",					&xml_conf_set_slot_integer,					offsetof(struct fpm_worker_pool_config_s, rlimit_files) },
+		{ XML_CONF_SCALAR,		"rlimit_core",					&fpm_conf_set_rlimit_core,					0 },
+		{ XML_CONF_SCALAR,		"max_requests",					&xml_conf_set_slot_integer,					offsetof(struct fpm_worker_pool_config_s, max_requests) },
+		{ XML_CONF_SCALAR,		"catch_workers_output",			&fpm_conf_set_catch_workers_output,			0 },
+		{ XML_CONF_SUBSECTION,	"pm",							&fpm_conf_set_pm_subsection,				offsetof(struct fpm_worker_pool_config_s, pm) },
+		{ 0, 0, 0, 0 }
+	}
+};
+
+static struct xml_conf_section *fpm_conf_all_sections[] = {
+	&xml_section_fpm_global_options,
+	&xml_section_fpm_worker_pool_config,
+	0
+};
+
+static int fpm_evaluate_full_path(char **path)
+{
+	if (**path != '/') {
+		char *full_path;
+
+		full_path = malloc(sizeof(PHP_PREFIX) + strlen(*path) + 1);
+
+		if (!full_path) return -1;
+
+		sprintf(full_path, "%s/%s", PHP_PREFIX, *path);
+
+		free(*path);
+
+		*path = full_path;
+	}
+
+	return 0;
+}
+
+static int fpm_conf_process_all_pools()
+{
+	struct fpm_worker_pool_s *wp;
+
+	if (!fpm_worker_all_pools) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "at least one pool section must be specified in config file");
+		return -1;
+	}
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+
+		if (wp->config->listen_address && *wp->config->listen_address) {
+
+			wp->listen_address_domain = fpm_sockets_domain_from_address(wp->config->listen_address);
+
+			if (wp->listen_address_domain == FPM_AF_UNIX && *wp->config->listen_address != '/') {
+				fpm_evaluate_full_path(&wp->config->listen_address);
+			}
+
+		}
+		else {
+
+			wp->is_template = 1;
+
+		}
+
+		if (wp->config->request_slowlog_timeout) {
+#if HAVE_FPM_TRACE
+			if (! (wp->config->slowlog && *wp->config->slowlog)) {
+				zlog(ZLOG_STUFF, ZLOG_ERROR, "pool %s: 'slowlog' must be specified for use with 'request_slowlog_timeout'",
+					wp->config->name);
+				return -1;
+			}
+#else
+			static int warned = 0;
+
+			if (!warned) {
+				zlog(ZLOG_STUFF, ZLOG_WARNING, "pool %s: 'request_slowlog_timeout' is not supported on your system",
+					wp->config->name);
+				warned = 1;
+			}
+
+			wp->config->request_slowlog_timeout = 0;
+#endif
+		}
+
+		if (wp->config->request_slowlog_timeout && wp->config->slowlog && *wp->config->slowlog) {
+			int fd;
+
+			fpm_evaluate_full_path(&wp->config->slowlog);
+
+			if (wp->config->request_slowlog_timeout) {
+				fd = open(wp->config->slowlog, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR);
+
+				if (0 > fd) {
+					zlog(ZLOG_STUFF, ZLOG_SYSERROR, "open(%s) failed", wp->config->slowlog);
+					return -1;
+				}
+				close(fd);
+			}
+		}
+	}
+
+	return 0;
+}
+
+int fpm_conf_unlink_pid()
+{
+	if (fpm_global_config.pid_file) {
+
+		if (0 > unlink(fpm_global_config.pid_file)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "unlink(\"%s\") failed", fpm_global_config.pid_file);
+			return -1;
+		}
+
+	}
+
+	return 0;
+}
+
+int fpm_conf_write_pid()
+{
+	int fd;
+
+	if (fpm_global_config.pid_file) {
+		char buf[64];
+		int len;
+
+		unlink(fpm_global_config.pid_file);
+
+		fd = creat(fpm_global_config.pid_file, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
+
+		if (fd < 0) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "creat(\"%s\") failed", fpm_global_config.pid_file);
+			return -1;
+		}
+
+		len = sprintf(buf, "%d", (int) fpm_globals.parent_pid);
+
+		if (len != write(fd, buf, len)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "write() failed");
+			return -1;
+		}
+
+		close(fd);
+	}
+
+	return 0;
+}
+
+static int fpm_conf_post_process()
+{
+	if (fpm_global_config.pid_file) {
+		fpm_evaluate_full_path(&fpm_global_config.pid_file);
+	}
+
+	if (!fpm_global_config.error_log) {
+		fpm_global_config.error_log = strdup(PHP_FPM_LOG_PATH);
+	}
+
+	fpm_evaluate_full_path(&fpm_global_config.error_log);
+
+	if (0 > fpm_stdio_open_error_log(0)) {
+		return -1;
+	}
+
+	return fpm_conf_process_all_pools();
+}
+
+static void fpm_conf_cleanup(int which, void *arg)
+{
+	free(fpm_global_config.pid_file);
+	free(fpm_global_config.error_log);
+	fpm_global_config.pid_file = 0;
+	fpm_global_config.error_log = 0;
+}
+
+int fpm_conf_init_main()
+{
+	char *filename = fpm_globals.config;
+	char *err;
+
+	if (0 > xml_conf_sections_register(fpm_conf_all_sections)) {
+		return -1;
+	}
+
+	if (filename == NULL) {
+		filename = PHP_FPM_CONF_PATH;
+	}
+
+	err = xml_conf_load_file(filename);
+
+	if (err) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "failed to load configuration file: %s", err);
+		return -1;
+	}
+
+	if (0 > fpm_conf_post_process()) {
+		return -1;
+	}
+
+	xml_conf_clean();
+
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_conf_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_conf.h b/sapi/cgi/fpm/fpm_conf.h
new file mode 100644
index 0000000..4dd011e
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_conf.h
@@ -0,0 +1,73 @@
+
+	/* $Id: fpm_conf.h,v 1.12.2.2 2008/12/13 03:46:49 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_CONF_H
+#define FPM_CONF_H 1
+
+struct key_value_s;
+
+struct key_value_s {
+	struct key_value_s *next;
+	char *key;
+	char *value;
+};
+
+struct fpm_global_config_s {
+	int emergency_restart_threshold;
+	int emergency_restart_interval;
+	int process_control_timeout;
+	int daemonize;
+	char *pid_file;
+	char *error_log;
+};
+
+extern struct fpm_global_config_s fpm_global_config;
+
+struct fpm_pm_s {
+	int style;
+	int max_children;
+	struct {
+		int StartServers;
+		int MinSpareServers;
+		int MaxSpareServers;
+	} options_apache_like;
+};
+
+struct fpm_listen_options_s {
+	int backlog;
+	char *owner;
+	char *group;
+	char *mode;
+};
+
+struct fpm_worker_pool_config_s {
+	char *name;
+	char *listen_address;
+	struct fpm_listen_options_s *listen_options;
+	struct key_value_s *php_defines;
+	char *user;
+	char *group;
+	char *chroot;
+	char *chdir;
+	char *allowed_clients;
+	struct key_value_s *environment;
+	struct fpm_pm_s *pm;
+	int request_terminate_timeout;
+	int request_slowlog_timeout;
+	char *slowlog;
+	int max_requests;
+	int rlimit_files;
+	int rlimit_core;
+	unsigned catch_workers_output:1;
+};
+
+enum { PM_STYLE_STATIC = 1, PM_STYLE_APACHE_LIKE = 2 };
+
+int fpm_conf_init_main();
+int fpm_worker_pool_config_free(struct fpm_worker_pool_config_s *wpc);
+int fpm_conf_write_pid();
+int fpm_conf_unlink_pid();
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_config.h b/sapi/cgi/fpm/fpm_config.h
new file mode 100644
index 0000000..319b200
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_config.h
@@ -0,0 +1,39 @@
+
+	/* $Id: fpm_config.h,v 1.16 2008/05/25 00:30:43 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "php_config.h"
+#include "fpm_autoconf.h"
+
+
+/* Solaris does not have it */
+#ifndef INADDR_NONE
+#define INADDR_NONE (-1)
+#endif
+
+
+/* If we're not using GNU C, elide __attribute__ */
+#ifndef __GNUC__
+#  define  __attribute__(x)  /*NOTHING*/
+#endif
+
+
+/* Solaris does not have it */
+#ifndef timersub
+#define	timersub(tvp, uvp, vvp)						\
+	do {								\
+		(vvp)->tv_sec = (tvp)->tv_sec - (uvp)->tv_sec;		\
+		(vvp)->tv_usec = (tvp)->tv_usec - (uvp)->tv_usec;	\
+		if ((vvp)->tv_usec < 0) {				\
+			(vvp)->tv_sec--;				\
+			(vvp)->tv_usec += 1000000;			\
+		}							\
+	} while (0)
+#endif
+
+#if defined(HAVE_PTRACE) || defined(PROC_MEM_FILE) || defined(HAVE_MACH_VM_READ)
+#define HAVE_FPM_TRACE 1
+#else
+#define HAVE_FPM_TRACE 0
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_env.c b/sapi/cgi/fpm/fpm_env.c
new file mode 100644
index 0000000..624a9fe
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_env.c
@@ -0,0 +1,125 @@
+
+	/* $Id: fpm_env.c,v 1.15 2008/09/18 23:19:59 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#ifdef HAVE_ALLOCA_H
+#include <alloca.h>
+#endif
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+
+#include "fpm_env.h"
+#include "zlog.h"
+
+#ifndef HAVE_SETENV
+int setenv(char *name, char *value, int overwrite)
+{
+	int name_len = strlen(name);
+	int value_len = strlen(value);
+	char *var = alloca(name_len + 1 + value_len + 1);
+
+	memcpy(var, name, name_len);
+
+	var[name_len] = '=';
+
+	memcpy(var + name_len + 1, value, value_len);
+
+	var[name_len + 1 + value_len] = '\0';
+
+	return putenv(var);
+}
+#endif
+
+#ifndef HAVE_CLEARENV
+void clearenv()
+{
+	char **envp;
+	char *s;
+
+	/* this algo is the only one known to me
+		that works well on all systems */
+	while (*(envp = environ)) {
+		char *eq = strchr(*envp, '=');
+
+		s = strdup(*envp);
+
+		if (eq) s[eq - *envp] = '\0';
+
+		unsetenv(s);
+		free(s);
+	}
+
+}
+#endif
+
+
+int fpm_env_init_child(struct fpm_worker_pool_s *wp)
+{
+	struct key_value_s *kv;
+
+	clearenv();
+
+	for (kv = wp->config->environment; kv; kv = kv->next) {
+		setenv(kv->key, kv->value, 1);
+	}
+
+	if (wp->user) {
+		setenv("USER", wp->user, 1);
+	}
+
+	if (wp->home) {
+		setenv("HOME", wp->home, 1);
+	}
+
+	return 0;
+}
+
+static int fpm_env_conf_wp(struct fpm_worker_pool_s *wp)
+{
+	struct key_value_s *kv;
+
+	kv = wp->config->environment;
+
+	for (kv = wp->config->environment; kv; kv = kv->next) {
+		if (*kv->value == '$') {
+			char *value = getenv(kv->value + 1);
+
+			if (!value) value = "";
+
+			free(kv->value);
+			kv->value = strdup(value);
+		}
+
+		/* autodetected values should be removed
+			if these vars specified in config */
+		if (!strcmp(kv->key, "USER")) {
+			free(wp->user);
+			wp->user = 0;
+		}
+
+		if (!strcmp(kv->key, "HOME")) {
+			free(wp->home);
+			wp->home = 0;
+		}
+	}
+
+	return 0;
+}
+
+int fpm_env_init_main()
+{
+	struct fpm_worker_pool_s *wp;
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+
+		if (0 > fpm_env_conf_wp(wp)) {
+			return -1;
+		}
+
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_env.h b/sapi/cgi/fpm/fpm_env.h
new file mode 100644
index 0000000..0f79ed7
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_env.h
@@ -0,0 +1,24 @@
+
+	/* $Id: fpm_env.h,v 1.9 2008/09/18 23:19:59 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_ENV_H
+#define FPM_ENV_H 1
+
+#include "fpm_worker_pool.h"
+
+int fpm_env_init_child(struct fpm_worker_pool_s *wp);
+int fpm_env_init_main();
+
+extern char **environ;
+
+#ifndef HAVE_SETENV
+int setenv(char *name, char *value, int overwrite);
+#endif
+
+#ifndef HAVE_CLEARENV
+void clearenv();
+#endif
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_events.c b/sapi/cgi/fpm/fpm_events.c
new file mode 100644
index 0000000..654e9c8
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_events.c
@@ -0,0 +1,135 @@
+
+	/* $Id: fpm_events.c,v 1.21.2.2 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <unistd.h>
+#include <errno.h>
+#include <stdlib.h> /* for putenv */
+#include <string.h>
+#include <sys/types.h> /* for event.h below */
+#include <event.h>
+
+#include "fpm.h"
+#include "fpm_process_ctl.h"
+#include "fpm_events.h"
+#include "fpm_cleanup.h"
+#include "fpm_stdio.h"
+#include "fpm_signals.h"
+#include "fpm_children.h"
+#include "zlog.h"
+
+static void fpm_event_cleanup(int which, void *arg)
+{
+	event_base_free(0);
+}
+
+static void fpm_got_signal(int fd, short ev, void *arg)
+{
+	char c;
+	int res;
+
+	do {
+
+		do {
+			res = read(fd, &c, 1);
+		} while (res == -1 && errno == EINTR);
+
+		if (res <= 0) {
+			if (res < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "read() failed");
+			}
+			return;
+		}
+
+		switch (c) {
+			case 'C' :                  /* SIGCHLD */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGCHLD");
+				fpm_children_bury();
+				break;
+			case 'I' :                  /* SIGINT  */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGINT");
+				fpm_pctl(FPM_PCTL_STATE_TERMINATING, FPM_PCTL_ACTION_SET);
+				break;
+			case 'T' :                  /* SIGTERM */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGTERM");
+				fpm_pctl(FPM_PCTL_STATE_TERMINATING, FPM_PCTL_ACTION_SET);
+				break;
+			case 'Q' :                  /* SIGQUIT */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGQUIT");
+				fpm_pctl(FPM_PCTL_STATE_FINISHING, FPM_PCTL_ACTION_SET);
+				break;
+			case '1' :                  /* SIGUSR1 */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGUSR1");
+				if (0 == fpm_stdio_open_error_log(1)) {
+					zlog(ZLOG_STUFF, ZLOG_NOTICE, "log file re-opened");
+				}
+				break;
+			case '2' :                  /* SIGUSR2 */
+				zlog(ZLOG_STUFF, ZLOG_NOTICE, "received SIGUSR2");
+				fpm_pctl(FPM_PCTL_STATE_RELOADING, FPM_PCTL_ACTION_SET);
+				break;
+		}
+
+		if (fpm_globals.is_child) {
+			break;
+		}
+
+	} while (1);
+
+	return;
+}
+
+int fpm_event_init_main()
+{
+	event_init();
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "libevent: using %s", event_get_method());
+
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_event_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_event_loop()
+{
+	static struct event signal_fd_event;
+
+	event_set(&signal_fd_event, fpm_signals_get_fd(), EV_PERSIST | EV_READ, &fpm_got_signal, 0);
+
+	event_add(&signal_fd_event, 0);
+
+	fpm_pctl_heartbeat(-1, 0, 0);
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "libevent: entering main loop");
+
+	event_loop(0);
+
+	return 0;
+}
+
+int fpm_event_add(int fd, struct event *ev, void (*callback)(int, short, void *), void *arg)
+{
+	event_set(ev, fd, EV_PERSIST | EV_READ, callback, arg);
+
+	return event_add(ev, 0);
+}
+
+int fpm_event_del(struct event *ev)
+{
+	return event_del(ev);
+}
+
+void fpm_event_exit_loop()
+{
+	event_loopbreak();
+}
+
+void fpm_event_fire(struct event *ev)
+{
+	(*ev->ev_callback)( (int) ev->ev_fd, (short) ev->ev_res, ev->ev_arg);	
+}
+
diff --git a/sapi/cgi/fpm/fpm_events.h b/sapi/cgi/fpm/fpm_events.h
new file mode 100644
index 0000000..d5a45ce
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_events.h
@@ -0,0 +1,16 @@
+
+	/* $Id: fpm_events.h,v 1.9 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_EVENTS_H
+#define FPM_EVENTS_H 1
+
+void fpm_event_exit_loop();
+int fpm_event_loop();
+int fpm_event_add(int fd, struct event *ev, void (*callback)(int, short, void *), void *arg);
+int fpm_event_del(struct event *ev);
+void fpm_event_fire(struct event *ev);
+int fpm_event_init_main();
+
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_php.c b/sapi/cgi/fpm/fpm_php.c
new file mode 100644
index 0000000..fb46b9b
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_php.c
@@ -0,0 +1,190 @@
+
+	/* $Id: fpm_php.c,v 1.22.2.4 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <stdlib.h>
+#include <string.h>
+#include <stdio.h>
+
+#include "php.h"
+#include "php_main.h"
+#include "php_ini.h"
+#include "ext/standard/dl.h"
+
+#include "fastcgi.h"
+
+#include "fpm.h"
+#include "fpm_php.h"
+#include "fpm_cleanup.h"
+#include "fpm_worker_pool.h"
+
+static int zend_ini_alter_master(char *name, int name_length, char *new_value, int new_value_length, int stage TSRMLS_DC)
+{
+	zend_ini_entry *ini_entry;
+	char *duplicate;
+
+	if (zend_hash_find(EG(ini_directives), name, name_length, (void **) &ini_entry) == FAILURE) {
+		return FAILURE;
+	}
+
+	duplicate = strdup(new_value);
+
+	if (!ini_entry->on_modify
+		|| ini_entry->on_modify(ini_entry, duplicate, new_value_length,
+			ini_entry->mh_arg1, ini_entry->mh_arg2, ini_entry->mh_arg3, stage TSRMLS_CC) == SUCCESS) {
+		ini_entry->value = duplicate;
+		ini_entry->value_length = new_value_length;
+	} else {
+		free(duplicate);
+	}
+
+	return SUCCESS;
+}
+
+static void fpm_php_disable(char *value, int (*zend_disable)(char *, uint TSRMLS_DC) TSRMLS_DC)
+{
+	char *s = 0, *e = value;
+
+	while (*e) {
+		switch (*e) {
+			case ' ':
+			case ',':
+				if (s) {
+					*e = '\0';
+					zend_disable(s, e - s TSRMLS_CC);
+					s = 0;
+				}
+				break;
+			default:
+				if (!s) {
+					s = e;
+				}
+				break;
+		}
+		e++;
+	}
+
+	if (s) {
+		zend_disable(s, e - s TSRMLS_CC);
+	}
+}
+
+static int fpm_php_apply_defines(struct fpm_worker_pool_s *wp)
+{
+	TSRMLS_FETCH();
+	struct key_value_s *kv;
+
+	for (kv = wp->config->php_defines; kv; kv = kv->next) {
+		char *name = kv->key;
+		char *value = kv->value;
+		int name_len = strlen(name);
+		int value_len = strlen(value);
+
+		if (!strcmp(name, "extension") && *value) {
+			zval zv;
+
+#if defined(PHP_VERSION_ID) && (PHP_VERSION_ID >= 50300)
+			php_dl(value, MODULE_PERSISTENT, &zv, 1 TSRMLS_CC);
+#else
+			zval filename;
+			ZVAL_STRINGL(&filename, value, value_len, 0);
+#if (PHP_MAJOR_VERSION >= 5)
+			php_dl(&filename, MODULE_PERSISTENT, &zv, 1 TSRMLS_CC);
+#else
+			php_dl(&filename, MODULE_PERSISTENT, &zv TSRMLS_CC);
+#endif
+#endif
+			continue;
+		}
+
+		zend_ini_alter_master(name, name_len + 1, value, value_len, PHP_INI_STAGE_ACTIVATE TSRMLS_CC);
+
+		if (!strcmp(name, "disable_functions") && *value) {
+			char *v = strdup(value);
+#if (PHP_MAJOR_VERSION >= 5)
+			PG(disable_functions) = v;
+#endif
+			fpm_php_disable(v, zend_disable_function TSRMLS_CC);
+		}
+		else if (!strcmp(name, "disable_classes") && *value) {
+			char *v = strdup(value);
+#if (PHP_MAJOR_VERSION >= 5)
+			PG(disable_classes) = v;
+#endif
+			fpm_php_disable(v, zend_disable_class TSRMLS_CC);
+		}
+	}
+
+	return 0;
+}
+
+static int fpm_php_set_allowed_clients(struct fpm_worker_pool_s *wp)
+{
+	if (wp->listen_address_domain == FPM_AF_INET) {
+		fcgi_set_allowed_clients(wp->config->allowed_clients);
+	}
+
+	return 0;
+}
+
+static int fpm_php_set_fcgi_mgmt_vars(struct fpm_worker_pool_s *wp)
+{
+	char max_workers[10 + 1]; /* 4294967295 */
+	int len;
+
+	len = sprintf(max_workers, "%u", (unsigned int) wp->config->pm->max_children);
+
+	fcgi_set_mgmt_var("FCGI_MAX_CONNS", sizeof("FCGI_MAX_CONNS")-1, max_workers, len);
+	fcgi_set_mgmt_var("FCGI_MAX_REQS",  sizeof("FCGI_MAX_REQS")-1,  max_workers, len);
+
+	return 0;
+}
+
+char *fpm_php_script_filename(TSRMLS_D)
+{
+	return SG(request_info).path_translated;
+}
+
+char *fpm_php_request_method(TSRMLS_D)
+{
+	return (char *) SG(request_info).request_method;
+}
+
+size_t fpm_php_content_length(TSRMLS_D)
+{
+	return SG(request_info).content_length;
+}
+
+static void fpm_php_cleanup(int which, void *arg)
+{
+	TSRMLS_FETCH();
+	php_module_shutdown(TSRMLS_C);
+	sapi_shutdown();
+}
+
+void fpm_php_soft_quit()
+{
+	fcgi_set_in_shutdown(1);
+}
+
+int fpm_php_init_main()
+{
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_PARENT, fpm_php_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_php_init_child(struct fpm_worker_pool_s *wp)
+{
+	if (0 > fpm_php_apply_defines(wp) ||
+		0 > fpm_php_set_allowed_clients(wp) ||
+		0 > fpm_php_set_fcgi_mgmt_vars(wp)) {
+		return -1;
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_php.h b/sapi/cgi/fpm/fpm_php.h
new file mode 100644
index 0000000..a05464f
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_php.h
@@ -0,0 +1,22 @@
+
+	/* $Id: fpm_php.h,v 1.10.2.1 2008/11/15 00:57:24 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_PHP_H
+#define FPM_PHP_H 1
+
+#include <TSRM.h>
+
+#include "build-defs.h" /* for PHP_ defines */
+
+struct fpm_worker_pool_s;
+
+int fpm_php_init_child(struct fpm_worker_pool_s *wp);
+char *fpm_php_script_filename(TSRMLS_D);
+char *fpm_php_request_method(TSRMLS_D);
+size_t fpm_php_content_length(TSRMLS_D);
+void fpm_php_soft_quit();
+int fpm_php_init_main();
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_php_trace.c b/sapi/cgi/fpm/fpm_php_trace.c
new file mode 100644
index 0000000..25a0d71
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_php_trace.c
@@ -0,0 +1,171 @@
+
+	/* $Id: fpm_php_trace.c,v 1.27.2.1 2008/11/15 00:57:24 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#if HAVE_FPM_TRACE
+
+#include "php.h"
+#include "php_main.h"
+
+#include <stdio.h>
+#include <stddef.h>
+#include <stdint.h>
+#include <unistd.h>
+#include <sys/time.h>
+#include <sys/types.h>
+#include <errno.h>
+
+#include "fpm_trace.h"
+#include "fpm_php_trace.h"
+#include "fpm_children.h"
+#include "fpm_worker_pool.h"
+#include "fpm_process_ctl.h"
+
+#include "zlog.h"
+
+
+#define valid_ptr(p) ((p) && 0 == ((p) & (sizeof(long) - 1)))
+
+#if SIZEOF_LONG == 4
+#define PTR_FMT "08"
+#elif SIZEOF_LONG == 8
+#define PTR_FMT "016"
+#endif
+
+
+static int fpm_php_trace_dump(struct fpm_child_s *child, FILE *slowlog TSRMLS_DC)
+{
+	int callers_limit = 20;
+	pid_t pid = child->pid;
+	struct timeval tv;
+	static const int buf_size = 1024;
+	char buf[buf_size];
+	long execute_data;
+	long l;
+
+	gettimeofday(&tv, 0);
+
+	zlog_print_time(&tv, buf, buf_size);
+
+	fprintf(slowlog, "\n%s pid %d (pool %s)\n", buf, (int) pid, child->wp->config->name);
+
+	if (0 > fpm_trace_get_strz(buf, buf_size, (long) &SG(request_info).path_translated)) {
+		return -1;
+	}
+
+	fprintf(slowlog, "script_filename = %s\n", buf);
+
+	if (0 > fpm_trace_get_long((long) &EG(current_execute_data), &l)) {
+		return -1;
+	}
+
+	execute_data = l;
+
+	while (execute_data) {
+		long function;
+		uint lineno = 0;
+
+		fprintf(slowlog, "[0x%" PTR_FMT "lx] ", execute_data);
+
+		if (0 > fpm_trace_get_long(execute_data + offsetof(zend_execute_data, function_state.function), &l)) {
+			return -1;
+		}
+
+		function = l;
+
+		if (valid_ptr(function)) {
+			if (0 > fpm_trace_get_strz(buf, buf_size, function + offsetof(zend_function, common.function_name))) {
+				return -1;
+			}
+
+			fprintf(slowlog, "%s()", buf);
+		}
+		else {
+			fprintf(slowlog, "???");
+		}
+
+		if (0 > fpm_trace_get_long(execute_data + offsetof(zend_execute_data, op_array), &l)) {
+			return -1;
+		}
+
+		*buf = '\0';
+
+		if (valid_ptr(l)) {
+			long op_array = l;
+
+			if (0 > fpm_trace_get_strz(buf, buf_size, op_array + offsetof(zend_op_array, filename))) {
+				return -1;
+			}
+		}
+
+		if (0 > fpm_trace_get_long(execute_data + offsetof(zend_execute_data, opline), &l)) {
+			return -1;
+		}
+
+		if (valid_ptr(l)) {
+			long opline = l;
+			uint *lu = (uint *) &l;
+
+			if (0 > fpm_trace_get_long(opline + offsetof(struct _zend_op, lineno), &l)) {
+				return -1;
+			}
+
+			lineno = *lu;
+		}
+
+		fprintf(slowlog, " %s:%u\n", *buf ? buf : "unknown", lineno);
+
+		if (0 > fpm_trace_get_long(execute_data + offsetof(zend_execute_data, prev_execute_data), &l)) {
+			return -1;
+		}
+
+		execute_data = l;
+
+		if (0 == --callers_limit) {
+			break;
+		}
+	}
+
+	return 0;
+}
+
+void fpm_php_trace(struct fpm_child_s *child)
+{
+	TSRMLS_FETCH();
+	FILE *slowlog;
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "about to trace %d", (int) child->pid);
+
+	slowlog = fopen(child->wp->config->slowlog, "a+");
+
+	if (!slowlog) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fopen(%s) failed", child->wp->config->slowlog);
+		goto done0;
+	}
+
+	if (0 > fpm_trace_ready(child->pid)) {
+		goto done1;
+	}
+
+	if (0 > fpm_php_trace_dump(child, slowlog TSRMLS_CC)) {
+		fprintf(slowlog, "+++ dump failed\n");
+	}
+
+	if (0 > fpm_trace_close(child->pid)) {
+		goto done1;
+	}
+
+done1:
+	fclose(slowlog);
+
+done0:
+	fpm_pctl_kill(child->pid, FPM_PCTL_CONT);
+	child->tracer = 0;
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "finished trace of %d", (int) child->pid);
+}
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_php_trace.h b/sapi/cgi/fpm/fpm_php_trace.h
new file mode 100644
index 0000000..af5e456
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_php_trace.h
@@ -0,0 +1,13 @@
+
+	/* $Id: fpm_php_trace.h,v 1.2 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_PHP_TRACE_H
+#define FPM_PHP_TRACE_H 1
+
+struct fpm_child_s;
+
+void fpm_php_trace(struct fpm_child_s *);
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_process_ctl.c b/sapi/cgi/fpm/fpm_process_ctl.c
new file mode 100644
index 0000000..c9b69eb
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_process_ctl.c
@@ -0,0 +1,354 @@
+
+	/* $Id: fpm_process_ctl.c,v 1.19.2.2 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/types.h>
+#include <signal.h>
+#include <unistd.h>
+#include <stdlib.h>
+
+#include "fpm.h"
+#include "fpm_clock.h"
+#include "fpm_children.h"
+#include "fpm_signals.h"
+#include "fpm_events.h"
+#include "fpm_process_ctl.h"
+#include "fpm_cleanup.h"
+#include "fpm_request.h"
+#include "fpm_worker_pool.h"
+#include "zlog.h"
+
+
+static int fpm_state = FPM_PCTL_STATE_NORMAL;
+static int fpm_signal_sent = 0;
+
+
+static const char *fpm_state_names[] = {
+	[FPM_PCTL_STATE_NORMAL] = "normal",
+	[FPM_PCTL_STATE_RELOADING] = "reloading",
+	[FPM_PCTL_STATE_TERMINATING] = "terminating",
+	[FPM_PCTL_STATE_FINISHING] = "finishing"
+};
+
+static int saved_argc;
+static char **saved_argv;
+
+static void fpm_pctl_cleanup(int which, void *arg)
+{
+	int i;
+
+	if (which != FPM_CLEANUP_PARENT_EXEC) {
+
+		for (i = 0; i < saved_argc; i++) {
+			free(saved_argv[i]);
+		}
+
+		free(saved_argv);
+
+	}
+}
+
+static struct event pctl_event;
+
+static void fpm_pctl_action(int fd, short which, void *arg)
+{
+	evtimer_del(&pctl_event);
+
+	memset(&pctl_event, 0, sizeof(pctl_event));
+
+	fpm_pctl(FPM_PCTL_STATE_UNSPECIFIED, FPM_PCTL_ACTION_TIMEOUT);
+}
+
+static int fpm_pctl_timeout_set(int sec)
+{
+	struct timeval tv = { .tv_sec = sec, .tv_usec = 0 };
+
+	if (evtimer_initialized(&pctl_event)) {
+		evtimer_del(&pctl_event);
+	}
+
+	evtimer_set(&pctl_event, &fpm_pctl_action, 0);
+
+	evtimer_add(&pctl_event, &tv);
+
+	return 0;
+}
+
+static void fpm_pctl_exit()
+{
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "exiting, bye-bye!");
+
+	fpm_conf_unlink_pid();
+
+	fpm_cleanups_run(FPM_CLEANUP_PARENT_EXIT_MAIN);
+
+	exit(0);
+}
+
+#define optional_arg(c) (saved_argc > c ? ", \"" : ""), (saved_argc > c ? saved_argv[c] : ""), (saved_argc > c ? "\"" : "")
+
+static void fpm_pctl_exec()
+{
+
+	zlog(ZLOG_STUFF, ZLOG_NOTICE, "reloading: execvp(\"%s\", {\"%s\""
+			"%s%s%s" "%s%s%s" "%s%s%s" "%s%s%s" "%s%s%s"
+			"%s%s%s" "%s%s%s" "%s%s%s" "%s%s%s" "%s%s%s"
+		"})",
+		saved_argv[0], saved_argv[0],
+		optional_arg(1),
+		optional_arg(2),
+		optional_arg(3),
+		optional_arg(4),
+		optional_arg(5),
+		optional_arg(6),
+		optional_arg(7),
+		optional_arg(8),
+		optional_arg(9),
+		optional_arg(10)
+	);
+
+	fpm_cleanups_run(FPM_CLEANUP_PARENT_EXEC);
+
+	execvp(saved_argv[0], saved_argv);
+
+	zlog(ZLOG_STUFF, ZLOG_SYSERROR, "execvp() failed");
+
+	exit(1);
+}
+
+static void fpm_pctl_action_last()
+{
+	switch (fpm_state) {
+
+		case FPM_PCTL_STATE_RELOADING :
+
+			fpm_pctl_exec();
+			break;
+
+		case FPM_PCTL_STATE_FINISHING :
+
+		case FPM_PCTL_STATE_TERMINATING :
+
+			fpm_pctl_exit();
+			break;
+	}
+}
+
+int fpm_pctl_kill(pid_t pid, int how)
+{
+	int s = 0;
+
+	switch (how) {
+		case FPM_PCTL_TERM :
+			s = SIGTERM;
+			break;
+		case FPM_PCTL_STOP :
+			s = SIGSTOP;
+			break;
+		case FPM_PCTL_CONT :
+			s = SIGCONT;
+			break;
+		default :
+			break;
+	}
+
+	return kill(pid, s);
+}
+
+static void fpm_pctl_kill_all(int signo)
+{
+	struct fpm_worker_pool_s *wp;
+	int alive_children = 0;
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+		struct fpm_child_s *child;
+
+		for (child = wp->children; child; child = child->next) {
+
+			int res = kill(child->pid, signo);
+
+			zlog(ZLOG_STUFF, ZLOG_NOTICE, "sending signal %d %s to child %d (pool %s)", signo,
+				fpm_signal_names[signo] ? fpm_signal_names[signo] : "",
+				(int) child->pid, child->wp->config->name);
+
+			if (res == 0) ++alive_children;
+		}
+	}
+
+	if (alive_children) {
+		zlog(ZLOG_STUFF, ZLOG_NOTICE, "%d %s still alive", alive_children, alive_children == 1 ? "child is" : "children are");
+	}
+}
+
+static void fpm_pctl_action_next()
+{
+	int sig, timeout;
+
+	if (!fpm_globals.running_children) fpm_pctl_action_last();
+
+	if (fpm_signal_sent == 0) {
+		if (fpm_state == FPM_PCTL_STATE_TERMINATING) {
+			sig = SIGTERM;
+		}
+		else {
+			sig = SIGQUIT;
+		}
+		timeout = fpm_global_config.process_control_timeout;
+	}
+	else {
+		if (fpm_signal_sent == SIGQUIT) {
+			sig = SIGTERM;
+		}
+		else {
+			sig = SIGKILL;
+		}
+		timeout = 1;
+	}
+
+	fpm_pctl_kill_all(sig);
+
+	fpm_signal_sent = sig;
+
+	fpm_pctl_timeout_set(timeout);
+}
+
+void fpm_pctl(int new_state, int action)
+{
+	switch (action) {
+
+		case FPM_PCTL_ACTION_SET :
+
+			if (fpm_state == new_state) { /* already in progress - just ignore duplicate signal */
+				return;
+			}
+
+			switch (fpm_state) { /* check which states can be overridden */
+
+				case FPM_PCTL_STATE_NORMAL :
+
+					/* 'normal' can be overridden by any other state */
+					break;
+
+				case FPM_PCTL_STATE_RELOADING :
+
+					/* 'reloading' can be overridden by 'finishing' */
+					if (new_state == FPM_PCTL_STATE_FINISHING) break;
+
+				case FPM_PCTL_STATE_FINISHING :
+
+					/* 'reloading' and 'finishing' can be overridden by 'terminating' */
+					if (new_state == FPM_PCTL_STATE_TERMINATING) break;
+
+				case FPM_PCTL_STATE_TERMINATING :
+
+					/* nothing can override 'terminating' state */
+					zlog(ZLOG_STUFF, ZLOG_NOTICE, "not switching to '%s' state, because already in '%s' state",
+						fpm_state_names[new_state], fpm_state_names[fpm_state]);
+
+					return;
+			}
+
+			fpm_signal_sent = 0;
+			fpm_state = new_state;
+
+			zlog(ZLOG_STUFF, ZLOG_NOTICE, "switching to '%s' state", fpm_state_names[fpm_state]);
+
+			/* fall down */
+
+		case FPM_PCTL_ACTION_TIMEOUT :
+
+			fpm_pctl_action_next();
+
+			break;
+
+		case FPM_PCTL_ACTION_LAST_CHILD_EXITED :
+
+			fpm_pctl_action_last();
+
+			break;
+
+	}
+}
+
+int fpm_pctl_can_spawn_children()
+{
+	return fpm_state == FPM_PCTL_STATE_NORMAL;
+}
+
+int fpm_pctl_child_exited()
+{
+	if (fpm_state == FPM_PCTL_STATE_NORMAL) return 0;
+
+	if (!fpm_globals.running_children) {
+		fpm_pctl(FPM_PCTL_STATE_UNSPECIFIED, FPM_PCTL_ACTION_LAST_CHILD_EXITED);
+	}
+
+	return 0;
+}
+
+int fpm_pctl_init_main()
+{
+	int i;
+
+	saved_argc = fpm_globals.argc;
+
+	saved_argv = malloc(sizeof(char *) * (saved_argc + 1));
+
+	if (!saved_argv) {
+		return -1;
+	}
+
+	for (i = 0; i < saved_argc; i++) {
+		saved_argv[i] = strdup(fpm_globals.argv[i]);
+
+		if (!saved_argv[i]) {
+			return -1;
+		}
+	}
+
+	saved_argv[i] = 0;
+
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_pctl_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
+
+static void fpm_pctl_check_request_timeout(struct timeval *now)
+{
+	struct fpm_worker_pool_s *wp;
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+		int terminate_timeout = wp->config->request_terminate_timeout;
+		int slowlog_timeout = wp->config->request_slowlog_timeout;
+		struct fpm_child_s *child;
+
+		if (terminate_timeout || slowlog_timeout) {
+			for (child = wp->children; child; child = child->next) {
+				fpm_request_check_timed_out(child, now, terminate_timeout, slowlog_timeout);
+			}
+		}
+	}
+	
+}
+
+void fpm_pctl_heartbeat(int fd, short which, void *arg)
+{
+	static struct event heartbeat;
+	struct timeval tv = { .tv_sec = 0, .tv_usec = 130000 };
+	struct timeval now;
+
+	if (which == EV_TIMEOUT) {
+		evtimer_del(&heartbeat);
+		fpm_clock_get(&now);
+		fpm_pctl_check_request_timeout(&now);
+	}
+
+	evtimer_set(&heartbeat, &fpm_pctl_heartbeat, 0);
+
+	evtimer_add(&heartbeat, &tv);
+}
+
diff --git a/sapi/cgi/fpm/fpm_process_ctl.h b/sapi/cgi/fpm/fpm_process_ctl.h
new file mode 100644
index 0000000..8424f10
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_process_ctl.h
@@ -0,0 +1,39 @@
+
+	/* $Id: fpm_process_ctl.h,v 1.6 2008/07/20 21:33:10 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_PROCESS_CTL_H
+#define FPM_PROCESS_CTL_H 1
+
+struct fpm_child_s;
+
+void fpm_pctl(int new_state, int action);
+int fpm_pctl_can_spawn_children();
+int fpm_pctl_kill(pid_t pid, int how);
+void fpm_pctl_heartbeat(int fd, short which, void *arg);
+int fpm_pctl_child_exited();
+int fpm_pctl_init_main();
+
+
+enum {
+	FPM_PCTL_STATE_UNSPECIFIED,
+	FPM_PCTL_STATE_NORMAL,
+	FPM_PCTL_STATE_RELOADING,
+	FPM_PCTL_STATE_TERMINATING,
+	FPM_PCTL_STATE_FINISHING
+};
+
+enum {
+	FPM_PCTL_ACTION_SET,
+	FPM_PCTL_ACTION_TIMEOUT,
+	FPM_PCTL_ACTION_LAST_CHILD_EXITED
+};
+
+enum {
+	FPM_PCTL_TERM,
+	FPM_PCTL_STOP,
+	FPM_PCTL_CONT
+};
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_request.c b/sapi/cgi/fpm/fpm_request.c
new file mode 100644
index 0000000..3faf77d
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_request.c
@@ -0,0 +1,164 @@
+
+	/* $Id: fpm_request.c,v 1.9.2.1 2008/11/15 00:57:24 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include "fpm_php.h"
+#include "fpm_str.h"
+#include "fpm_clock.h"
+#include "fpm_conf.h"
+#include "fpm_trace.h"
+#include "fpm_php_trace.h"
+#include "fpm_process_ctl.h"
+#include "fpm_children.h"
+#include "fpm_shm_slots.h"
+#include "fpm_request.h"
+
+#include "zlog.h"
+
+void fpm_request_accepting()
+{
+	struct fpm_shm_slot_s *slot;
+
+	slot = fpm_shm_slots_acquire(0, 0);
+
+	slot->request_stage = FPM_REQUEST_ACCEPTING;
+
+	fpm_clock_get(&slot->tv);
+	memset(slot->request_method, 0, sizeof(slot->request_method));
+	slot->content_length = 0;
+	memset(slot->script_filename, 0, sizeof(slot->script_filename));
+
+	fpm_shm_slots_release(slot);
+}
+
+void fpm_request_reading_headers()
+{
+	struct fpm_shm_slot_s *slot;
+
+	slot = fpm_shm_slots_acquire(0, 0);
+
+	slot->request_stage = FPM_REQUEST_READING_HEADERS;
+
+	fpm_clock_get(&slot->tv);
+	slot->accepted = slot->tv;
+
+	fpm_shm_slots_release(slot);
+}
+
+void fpm_request_info()
+{
+	TSRMLS_FETCH();
+	struct fpm_shm_slot_s *slot;
+	char *request_method = fpm_php_request_method(TSRMLS_C);
+	char *script_filename = fpm_php_script_filename(TSRMLS_C);
+
+	slot = fpm_shm_slots_acquire(0, 0);
+
+	slot->request_stage = FPM_REQUEST_INFO;
+
+	fpm_clock_get(&slot->tv);
+
+	if (request_method) {
+		cpystrn(slot->request_method, request_method, sizeof(slot->request_method));
+	}
+
+	slot->content_length = fpm_php_content_length(TSRMLS_C);
+
+	/* if cgi.fix_pathinfo is set to "1" and script cannot be found (404)
+		the sapi_globals.request_info.path_translated is set to NULL */
+	if (script_filename) {
+		cpystrn(slot->script_filename, script_filename, sizeof(slot->script_filename));
+	}
+
+	fpm_shm_slots_release(slot);
+}
+
+void fpm_request_executing()
+{
+	struct fpm_shm_slot_s *slot;
+
+	slot = fpm_shm_slots_acquire(0, 0);
+
+	slot->request_stage = FPM_REQUEST_EXECUTING;
+
+	fpm_clock_get(&slot->tv);
+
+	fpm_shm_slots_release(slot);
+}
+
+void fpm_request_finished()
+{
+	struct fpm_shm_slot_s *slot;
+
+	slot = fpm_shm_slots_acquire(0, 0);
+
+	slot->request_stage = FPM_REQUEST_FINISHED;
+
+	fpm_clock_get(&slot->tv);
+	memset(&slot->accepted, 0, sizeof(slot->accepted));
+
+	fpm_shm_slots_release(slot);
+}
+
+void fpm_request_check_timed_out(struct fpm_child_s *child, struct timeval *now, int terminate_timeout, int slowlog_timeout)
+{
+	struct fpm_shm_slot_s *slot;
+	struct fpm_shm_slot_s slot_c;
+
+	slot = fpm_shm_slot(child);
+
+	if (!fpm_shm_slots_acquire(slot, 1)) {
+		return;
+	}
+
+	slot_c = *slot;
+
+	fpm_shm_slots_release(slot);
+
+#if HAVE_FPM_TRACE
+	if (child->slow_logged.tv_sec) {
+		if (child->slow_logged.tv_sec != slot_c.accepted.tv_sec || child->slow_logged.tv_usec != slot_c.accepted.tv_usec) {
+			child->slow_logged.tv_sec = 0;
+			child->slow_logged.tv_usec = 0;
+		}
+	}
+#endif
+
+	if (slot_c.request_stage > FPM_REQUEST_ACCEPTING && slot_c.request_stage < FPM_REQUEST_FINISHED) {
+		char purified_script_filename[sizeof(slot_c.script_filename)];
+		struct timeval tv;
+
+		timersub(now, &slot_c.accepted, &tv);
+
+#if HAVE_FPM_TRACE
+		if (child->slow_logged.tv_sec == 0 && slowlog_timeout &&
+				slot_c.request_stage == FPM_REQUEST_EXECUTING && tv.tv_sec >= slowlog_timeout) {
+			
+			str_purify_filename(purified_script_filename, slot_c.script_filename, sizeof(slot_c.script_filename));
+
+			child->slow_logged = slot_c.accepted;
+			child->tracer = fpm_php_trace;
+
+			fpm_trace_signal(child->pid);
+
+			zlog(ZLOG_STUFF, ZLOG_WARNING, "child %d, script '%s' (pool %s) executing too slow (%d.%06d sec), logging",
+				(int) child->pid, purified_script_filename, child->wp->config->name, (int) tv.tv_sec, (int) tv.tv_usec);
+		}
+
+		else
+#endif
+		if (terminate_timeout && tv.tv_sec >= terminate_timeout) {
+
+			str_purify_filename(purified_script_filename, slot_c.script_filename, sizeof(slot_c.script_filename));
+
+			fpm_pctl_kill(child->pid, FPM_PCTL_TERM);
+
+			zlog(ZLOG_STUFF, ZLOG_WARNING, "child %d, script '%s' (pool %s) execution timed out (%d.%06d sec), terminating",
+				(int) child->pid, purified_script_filename, child->wp->config->name, (int) tv.tv_sec, (int) tv.tv_usec);
+		}
+	}
+
+}
+
diff --git a/sapi/cgi/fpm/fpm_request.h b/sapi/cgi/fpm/fpm_request.h
new file mode 100644
index 0000000..d768db6
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_request.h
@@ -0,0 +1,27 @@
+
+	/* $Id: fpm_request.h,v 1.4 2008/07/20 01:47:16 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_REQUEST_H
+#define FPM_REQUEST_H 1
+
+void fpm_request_accepting();				/* hanging in accept() */
+void fpm_request_reading_headers();			/* start reading fastcgi request from very first byte */
+void fpm_request_info();					/* not a stage really but a point in the php code, where all request params have become known to sapi */
+void fpm_request_executing();				/* the script is executing */
+void fpm_request_finished();				/* request processed: script response have been sent to web server */
+
+struct fpm_child_s;
+struct timeval;
+
+void fpm_request_check_timed_out(struct fpm_child_s *child, struct timeval *tv, int terminate_timeout, int slowlog_timeout);
+
+enum fpm_request_stage_e {
+	FPM_REQUEST_ACCEPTING = 1,
+	FPM_REQUEST_READING_HEADERS,
+	FPM_REQUEST_INFO,
+	FPM_REQUEST_EXECUTING,
+	FPM_REQUEST_FINISHED
+};
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_shm.c b/sapi/cgi/fpm/fpm_shm.c
new file mode 100644
index 0000000..21c3d75
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_shm.c
@@ -0,0 +1,100 @@
+
+	/* $Id: fpm_shm.c,v 1.3 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <unistd.h>
+#include <sys/mman.h>
+#include <stdlib.h>
+
+#include "fpm_shm.h"
+#include "zlog.h"
+
+
+/* MAP_ANON is depricated, but not in macosx */
+#if defined(MAP_ANON) && !defined(MAP_ANONYMOUS)
+#define MAP_ANONYMOUS MAP_ANON
+#endif
+
+
+struct fpm_shm_s *fpm_shm_alloc(size_t sz)
+{
+	struct fpm_shm_s *shm;
+
+	shm = malloc(sizeof(*shm));
+
+	if (!shm) {
+		return 0;
+	}
+
+	shm->mem = mmap(0, sz, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_SHARED, -1, 0);
+
+	if (!shm->mem) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "mmap(MAP_ANONYMOUS | MAP_SHARED) failed");
+		free(shm);
+		return 0;
+	}
+
+	shm->used = 0;
+	shm->sz = sz;
+
+	return shm;
+}
+
+static void fpm_shm_free(struct fpm_shm_s *shm, int do_unmap)
+{
+	if (do_unmap) {
+		munmap(shm->mem, shm->sz);
+	}
+
+	free(shm);	
+}
+
+void fpm_shm_free_list(struct fpm_shm_s *shm, void *mem)
+{
+	struct fpm_shm_s *next;
+
+	for (; shm; shm = next) {
+		next = shm->next;
+
+		fpm_shm_free(shm, mem != shm->mem);
+	}
+}
+
+void *fpm_shm_alloc_chunk(struct fpm_shm_s **head, size_t sz, void **mem)
+{
+	size_t pagesize = getpagesize();
+	static const size_t cache_line_size = 16;
+	size_t aligned_sz;
+	struct fpm_shm_s *shm;
+	void *ret;
+
+	sz = (sz + cache_line_size - 1) & -cache_line_size;
+
+	shm = *head;
+
+	if (0 == shm || shm->sz - shm->used < sz) {
+		/* allocate one more shm segment */
+
+		aligned_sz = (sz + pagesize - 1) & -pagesize;
+
+		shm = fpm_shm_alloc(aligned_sz);
+
+		if (!shm) {
+			return 0;
+		}
+
+		shm->next = *head;
+		if (shm->next) shm->next->prev = shm;
+		shm->prev = 0;
+		*head = shm;
+	}
+
+	*mem = shm->mem;
+	ret = (char *) shm->mem + shm->used;
+	shm->used += sz;
+
+	return ret;
+}
+
diff --git a/sapi/cgi/fpm/fpm_shm.h b/sapi/cgi/fpm/fpm_shm.h
new file mode 100644
index 0000000..f3f0be0
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_shm.h
@@ -0,0 +1,22 @@
+
+	/* $Id: fpm_shm.h,v 1.3 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_SHM_H
+#define FPM_SHM_H 1
+
+struct fpm_shm_s;
+
+struct fpm_shm_s {
+	struct fpm_shm_s *prev, *next;
+	void *mem;
+	size_t sz;
+	size_t used;
+};
+
+struct fpm_shm_s *fpm_shm_alloc(size_t sz);
+void fpm_shm_free_list(struct fpm_shm_s *, void *);
+void *fpm_shm_alloc_chunk(struct fpm_shm_s **head, size_t sz, void **mem);
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_shm_slots.c b/sapi/cgi/fpm/fpm_shm_slots.c
new file mode 100644
index 0000000..efa3707
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_shm_slots.c
@@ -0,0 +1,127 @@
+
+	/* $Id: fpm_shm_slots.c,v 1.2 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include "fpm_atomic.h"
+#include "fpm_worker_pool.h"
+#include "fpm_children.h"
+#include "fpm_shm.h"
+#include "fpm_shm_slots.h"
+#include "zlog.h"
+
+static void *shm_mem;
+static struct fpm_shm_slot_s *shm_slot;
+
+int fpm_shm_slots_prepare_slot(struct fpm_child_s *child)
+{
+	struct fpm_worker_pool_s *wp = child->wp;
+	struct fpm_shm_slot_ptr_s *shm_slot_ptr;
+
+	child->shm_slot_i = wp->slots_used.used;
+
+	shm_slot_ptr = fpm_array_push(&wp->slots_used);
+
+	if (0 == shm_slot_ptr) {
+		return -1;
+	}
+
+	if (0 == wp->slots_free.used) {
+		shm_slot_ptr->shm_slot = fpm_shm_alloc_chunk(&wp->shm_list, sizeof(struct fpm_shm_slot_s), &shm_slot_ptr->mem);
+
+		if (!shm_slot_ptr->shm_slot) {
+			return -1;
+		}
+	}
+	else {
+		*shm_slot_ptr = *(struct fpm_shm_slot_ptr_s *) fpm_array_item_last(&wp->slots_free);
+
+		--wp->slots_free.used;
+	}
+
+	memset(shm_slot_ptr->shm_slot, 0, sizeof(struct fpm_shm_slot_s));
+
+	shm_slot_ptr->child = child;
+
+	return 0;
+}
+
+void fpm_shm_slots_discard_slot(struct fpm_child_s *child)
+{
+	struct fpm_shm_slot_ptr_s *shm_slot_ptr;
+	struct fpm_worker_pool_s *wp = child->wp;
+	int n;
+
+	shm_slot_ptr = fpm_array_push(&wp->slots_free);
+
+	if (shm_slot_ptr) {
+
+		struct fpm_shm_slot_ptr_s *shm_slot_ptr_used;
+
+		shm_slot_ptr_used = fpm_array_item(&wp->slots_used, child->shm_slot_i);
+
+		*shm_slot_ptr = *shm_slot_ptr_used;
+
+		shm_slot_ptr->child = 0;
+
+	}
+
+	n = fpm_array_item_remove(&wp->slots_used, child->shm_slot_i);
+
+	if (n > -1) {
+		shm_slot_ptr = fpm_array_item(&wp->slots_used, n);
+
+		shm_slot_ptr->child->shm_slot_i = n;
+	}
+}
+
+void fpm_shm_slots_child_use_slot(struct fpm_child_s *child)
+{
+	struct fpm_shm_slot_ptr_s *shm_slot_ptr;
+	struct fpm_worker_pool_s *wp = child->wp;
+
+	shm_slot_ptr = fpm_array_item(&wp->slots_used, child->shm_slot_i);
+
+	shm_slot = shm_slot_ptr->shm_slot;
+	shm_mem = shm_slot_ptr->mem;
+}
+
+void fpm_shm_slots_parent_use_slot(struct fpm_child_s *child)
+{
+	/* nothing to do */
+}
+
+void *fpm_shm_slots_mem()
+{
+	return shm_mem;
+}
+
+struct fpm_shm_slot_s *fpm_shm_slot(struct fpm_child_s *child)
+{
+	struct fpm_shm_slot_ptr_s *shm_slot_ptr;
+	struct fpm_worker_pool_s *wp = child->wp;
+
+	shm_slot_ptr = fpm_array_item(&wp->slots_used, child->shm_slot_i);
+
+	return shm_slot_ptr->shm_slot;
+}
+
+struct fpm_shm_slot_s *fpm_shm_slots_acquire(struct fpm_shm_slot_s *s, int nohang)
+{
+	if (s == 0) {
+		s = shm_slot;
+	}
+
+	if (0 > fpm_spinlock(&s->lock, nohang)) {
+		return 0;
+	}
+
+	return s;
+}
+
+void fpm_shm_slots_release(struct fpm_shm_slot_s *s)
+{
+	s->lock = 0;
+}
+
diff --git a/sapi/cgi/fpm/fpm_shm_slots.h b/sapi/cgi/fpm/fpm_shm_slots.h
new file mode 100644
index 0000000..4596c6f
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_shm_slots.h
@@ -0,0 +1,43 @@
+
+	/* $Id: fpm_shm_slots.h,v 1.2 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_SHM_SLOTS_H
+#define FPM_SHM_SLOTS_H 1
+
+#include "fpm_atomic.h"
+#include "fpm_worker_pool.h"
+#include "fpm_request.h"
+
+struct fpm_child_s;
+
+struct fpm_shm_slot_s {
+	union {
+		atomic_t lock;
+		char dummy[16];
+	};
+	enum fpm_request_stage_e request_stage;
+	struct timeval accepted;
+	struct timeval tv;
+	char request_method[16];
+	size_t content_length; /* used with POST only */
+	char script_filename[256];
+};
+
+struct fpm_shm_slot_ptr_s {
+	void *mem;
+	struct fpm_shm_slot_s *shm_slot;
+	struct fpm_child_s *child;
+};
+
+int fpm_shm_slots_prepare_slot(struct fpm_child_s *child);
+void fpm_shm_slots_discard_slot(struct fpm_child_s *child);
+void fpm_shm_slots_child_use_slot(struct fpm_child_s *child);
+void fpm_shm_slots_parent_use_slot(struct fpm_child_s *child);
+void *fpm_shm_slots_mem();
+struct fpm_shm_slot_s *fpm_shm_slot(struct fpm_child_s *child);
+struct fpm_shm_slot_s *fpm_shm_slots_acquire(struct fpm_shm_slot_s *, int nohang);
+void fpm_shm_slots_release(struct fpm_shm_slot_s *);
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_signals.c b/sapi/cgi/fpm/fpm_signals.c
new file mode 100644
index 0000000..2cf878d
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_signals.c
@@ -0,0 +1,252 @@
+
+	/* $Id: fpm_signals.c,v 1.24 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <signal.h>
+#include <stdio.h>
+#include <sys/types.h>
+#include <sys/socket.h>
+#include <stdlib.h>
+#include <string.h>
+#include <fcntl.h>
+#include <unistd.h>
+#include <errno.h>
+
+#include "fpm.h"
+#include "fpm_signals.h"
+#include "fpm_sockets.h"
+#include "fpm_php.h"
+#include "zlog.h"
+
+static int sp[2];
+
+const char *fpm_signal_names[NSIG + 1] = {
+#ifdef SIGHUP
+	[SIGHUP] 		= "SIGHUP",
+#endif
+#ifdef SIGINT
+	[SIGINT] 		= "SIGINT",
+#endif
+#ifdef SIGQUIT
+	[SIGQUIT] 		= "SIGQUIT",
+#endif
+#ifdef SIGILL
+	[SIGILL] 		= "SIGILL",
+#endif
+#ifdef SIGTRAP
+	[SIGTRAP] 		= "SIGTRAP",
+#endif
+#ifdef SIGABRT
+	[SIGABRT] 		= "SIGABRT",
+#endif
+#ifdef SIGEMT
+	[SIGEMT] 		= "SIGEMT",
+#endif
+#ifdef SIGBUS
+	[SIGBUS] 		= "SIGBUS",
+#endif
+#ifdef SIGFPE
+	[SIGFPE] 		= "SIGFPE",
+#endif
+#ifdef SIGKILL
+	[SIGKILL] 		= "SIGKILL",
+#endif
+#ifdef SIGUSR1
+	[SIGUSR1] 		= "SIGUSR1",
+#endif
+#ifdef SIGSEGV
+	[SIGSEGV] 		= "SIGSEGV",
+#endif
+#ifdef SIGUSR2
+	[SIGUSR2] 		= "SIGUSR2",
+#endif
+#ifdef SIGPIPE
+	[SIGPIPE] 		= "SIGPIPE",
+#endif
+#ifdef SIGALRM
+	[SIGALRM] 		= "SIGALRM",
+#endif
+#ifdef SIGTERM
+	[SIGTERM] 		= "SIGTERM",
+#endif
+#ifdef SIGCHLD
+	[SIGCHLD] 		= "SIGCHLD",
+#endif
+#ifdef SIGCONT
+	[SIGCONT] 		= "SIGCONT",
+#endif
+#ifdef SIGSTOP
+	[SIGSTOP] 		= "SIGSTOP",
+#endif
+#ifdef SIGTSTP
+	[SIGTSTP] 		= "SIGTSTP",
+#endif
+#ifdef SIGTTIN
+	[SIGTTIN] 		= "SIGTTIN",
+#endif
+#ifdef SIGTTOU
+	[SIGTTOU] 		= "SIGTTOU",
+#endif
+#ifdef SIGURG
+	[SIGURG] 		= "SIGURG",
+#endif
+#ifdef SIGXCPU
+	[SIGXCPU] 		= "SIGXCPU",
+#endif
+#ifdef SIGXFSZ
+	[SIGXFSZ] 		= "SIGXFSZ",
+#endif
+#ifdef SIGVTALRM
+	[SIGVTALRM] 	= "SIGVTALRM",
+#endif
+#ifdef SIGPROF
+	[SIGPROF] 		= "SIGPROF",
+#endif
+#ifdef SIGWINCH
+	[SIGWINCH] 		= "SIGWINCH",
+#endif
+#ifdef SIGINFO
+	[SIGINFO] 		= "SIGINFO",
+#endif
+#ifdef SIGIO
+	[SIGIO] 		= "SIGIO",
+#endif
+#ifdef SIGPWR
+	[SIGPWR] 		= "SIGPWR",
+#endif
+#ifdef SIGSYS
+	[SIGSYS] 		= "SIGSYS",
+#endif
+#ifdef SIGWAITING
+	[SIGWAITING] 	= "SIGWAITING",
+#endif
+#ifdef SIGLWP
+	[SIGLWP] 		= "SIGLWP",
+#endif
+#ifdef SIGFREEZE
+	[SIGFREEZE] 	= "SIGFREEZE",
+#endif
+#ifdef SIGTHAW
+	[SIGTHAW] 		= "SIGTHAW",
+#endif
+#ifdef SIGCANCEL
+	[SIGCANCEL] 	= "SIGCANCEL",
+#endif
+#ifdef SIGLOST
+	[SIGLOST] 		= "SIGLOST",
+#endif
+};
+
+static void sig_soft_quit(int signo)
+{
+	int saved_errno = errno;
+
+	/* closing fastcgi listening socket will force fcgi_accept() exit immediately */
+	close(0);
+	socket(AF_UNIX, SOCK_STREAM, 0);
+
+	fpm_php_soft_quit();
+
+	errno = saved_errno;
+}
+
+static void sig_handler(int signo)
+{
+	static const char sig_chars[NSIG + 1] = {
+		[SIGTERM] = 'T',
+		[SIGINT]  = 'I',
+		[SIGUSR1] = '1',
+		[SIGUSR2] = '2',
+		[SIGQUIT] = 'Q',
+		[SIGCHLD] = 'C'
+	};
+	char s;
+	int saved_errno;
+
+	if (fpm_globals.parent_pid != getpid()) {
+		/* prevent a signal race condition when child process
+			have not set up it's own signal handler yet */
+		return;
+	}
+
+	saved_errno = errno;
+
+	s = sig_chars[signo];
+
+	write(sp[1], &s, sizeof(s));
+
+	errno = saved_errno;
+}
+
+int fpm_signals_init_main()
+{
+	struct sigaction act;
+
+	if (0 > socketpair(AF_UNIX, SOCK_STREAM, 0, sp)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "socketpair() failed");
+		return -1;
+	}
+
+	if (0 > fd_set_blocked(sp[0], 0) || 0 > fd_set_blocked(sp[1], 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fd_set_blocked() failed");
+		return -1;
+	}
+
+	if (0 > fcntl(sp[0], F_SETFD, FD_CLOEXEC) || 0 > fcntl(sp[1], F_SETFD, FD_CLOEXEC)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fcntl(F_SETFD, FD_CLOEXEC) failed");
+		return -1;
+	}
+
+	memset(&act, 0, sizeof(act));
+	act.sa_handler = sig_handler;
+	sigfillset(&act.sa_mask);
+
+	if (0 > sigaction(SIGTERM,  &act, 0) ||
+		0 > sigaction(SIGINT,   &act, 0) ||
+		0 > sigaction(SIGUSR1,  &act, 0) ||
+		0 > sigaction(SIGUSR2,  &act, 0) ||
+		0 > sigaction(SIGCHLD,  &act, 0) ||
+		0 > sigaction(SIGQUIT,  &act, 0)) {
+
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "sigaction() failed");
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_signals_init_child()
+{
+	struct sigaction act, act_dfl;
+
+	memset(&act, 0, sizeof(act));
+	memset(&act_dfl, 0, sizeof(act_dfl));
+
+	act.sa_handler = &sig_soft_quit;
+	act.sa_flags |= SA_RESTART;
+
+	act_dfl.sa_handler = SIG_DFL;
+
+	close(sp[0]);
+	close(sp[1]);
+
+	if (0 > sigaction(SIGTERM,  &act_dfl,  0) ||
+		0 > sigaction(SIGINT,   &act_dfl,  0) ||
+		0 > sigaction(SIGUSR1,  &act_dfl,  0) ||
+		0 > sigaction(SIGUSR2,  &act_dfl,  0) ||
+		0 > sigaction(SIGCHLD,  &act_dfl,  0) ||
+		0 > sigaction(SIGQUIT,  &act,      0)) {
+
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "sigaction() failed");
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_signals_get_fd()
+{
+	return sp[0];
+}
diff --git a/sapi/cgi/fpm/fpm_signals.h b/sapi/cgi/fpm/fpm_signals.h
new file mode 100644
index 0000000..eb80fae
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_signals.h
@@ -0,0 +1,16 @@
+
+	/* $Id: fpm_signals.h,v 1.5 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_SIGNALS_H
+#define FPM_SIGNALS_H 1
+
+#include <signal.h>
+
+int fpm_signals_init_main();
+int fpm_signals_init_child();
+int fpm_signals_get_fd();
+
+extern const char *fpm_signal_names[NSIG + 1];
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_sockets.c b/sapi/cgi/fpm/fpm_sockets.c
new file mode 100644
index 0000000..5acb559
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_sockets.c
@@ -0,0 +1,427 @@
+
+	/* $Id: fpm_sockets.c,v 1.20.2.1 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#ifdef HAVE_ALLOCA_H
+#include <alloca.h>
+#endif
+#include <sys/types.h>
+#include <sys/stat.h> /* for chmod(2) */
+#include <sys/socket.h>
+#include <netinet/in.h>
+#include <arpa/inet.h>
+#include <sys/un.h>
+#include <netdb.h>
+#include <stdio.h>
+#include <stdlib.h>
+#include <string.h>
+#include <errno.h>
+#include <unistd.h>
+
+#include "zlog.h"
+#include "fpm_arrays.h"
+#include "fpm_sockets.h"
+#include "fpm_worker_pool.h"
+#include "fpm_unix.h"
+#include "fpm_str.h"
+#include "fpm_env.h"
+#include "fpm_cleanup.h"
+
+struct listening_socket_s {
+	int refcount;
+	int sock;
+	int type;
+	char *key;
+};
+
+static struct fpm_array_s sockets_list;
+
+static int fpm_sockets_resolve_af_inet(char *node, char *service, struct sockaddr_in *addr)
+{
+	struct addrinfo *res;
+	struct addrinfo hints;
+	int ret;
+
+	memset(&hints, 0, sizeof(hints));
+
+	hints.ai_family = AF_INET;
+
+	ret = getaddrinfo(node, service, &hints, &res);
+
+	if (ret != 0) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "can't resolve hostname '%s%s%s': getaddrinfo said: %s%s%s\n",
+					node, service ? ":" : "", service ? service : "",
+					gai_strerror(ret), ret == EAI_SYSTEM ? ", system error: " : "", ret == EAI_SYSTEM ? strerror(errno) : "");
+		return -1;
+	}
+
+	*addr = *(struct sockaddr_in *) res->ai_addr;
+
+	freeaddrinfo(res);
+
+	return 0;
+}
+
+enum { FPM_GET_USE_SOCKET = 1, FPM_STORE_SOCKET = 2, FPM_STORE_USE_SOCKET = 3 };
+
+static void fpm_sockets_cleanup(int which, void *arg)
+{
+	int i;
+	char *env_value = 0;
+	int p = 0;
+	struct listening_socket_s *ls = sockets_list.data;
+
+	for (i = 0; i < sockets_list.used; i++, ls++) {
+
+		if (which != FPM_CLEANUP_PARENT_EXEC) {
+
+			close(ls->sock);
+
+		}
+		else { /* on PARENT EXEC we want socket fds to be inherited through environment variable */
+			char fd[32];
+			sprintf(fd, "%d", ls->sock);
+			env_value = realloc(env_value, p + (p ? 1 : 0) + strlen(ls->key) + 1 + strlen(fd) + 1);
+			p += sprintf(env_value + p, "%s%s=%s", p ? "," : "", ls->key, fd);
+		}
+
+		if (which == FPM_CLEANUP_PARENT_EXIT_MAIN) {
+
+			if (ls->type == FPM_AF_UNIX) {
+				unlink(ls->key);
+			}
+
+		}
+
+		free(ls->key);
+	}
+
+	if (env_value) {
+		setenv("FPM_SOCKETS", env_value, 1);
+		free(env_value);
+	}
+
+	fpm_array_free(&sockets_list);
+}
+
+static int fpm_sockets_hash_op(int sock, struct sockaddr *sa, char *key, int type, int op)
+{
+
+	if (key == NULL) {
+
+		switch (type) {
+
+			case FPM_AF_INET : {
+				struct sockaddr_in *sa_in = (struct sockaddr_in *) sa;
+
+				key = alloca(sizeof("xxx.xxx.xxx.xxx:ppppp"));
+
+				sprintf(key, "%u.%u.%u.%u:%u", IPQUAD(&sa_in->sin_addr), (unsigned int) ntohs(sa_in->sin_port));
+
+				break;
+			}
+
+			case FPM_AF_UNIX : {
+				struct sockaddr_un *sa_un = (struct sockaddr_un *) sa;
+
+				key = alloca(strlen(sa_un->sun_path) + 1);
+
+				strcpy(key, sa_un->sun_path);
+
+				break;
+			}
+
+			default :
+
+				return -1;
+		}
+
+	}
+
+	switch (op) {
+
+		case FPM_GET_USE_SOCKET :
+		{
+
+			int i;
+			struct listening_socket_s *ls = sockets_list.data;
+
+			for (i = 0; i < sockets_list.used; i++, ls++) {
+
+				if (!strcmp(ls->key, key)) {
+					++ls->refcount;
+					return ls->sock;
+				}
+			}
+
+			break;
+		}
+
+		case FPM_STORE_SOCKET :			/* inherited socket */
+		case FPM_STORE_USE_SOCKET :		/* just created */
+		{
+
+			struct listening_socket_s *ls;
+
+			ls = fpm_array_push(&sockets_list);
+
+			if (!ls) {
+				break;
+			}
+
+			if (op == FPM_STORE_SOCKET) {
+				ls->refcount = 0;
+			}
+			else {
+				ls->refcount = 1;
+			}
+			ls->type = type;
+			ls->sock = sock;
+			ls->key = strdup(key);
+
+			return 0;
+
+		}
+	}
+
+	return -1;
+
+}
+
+static int fpm_sockets_new_listening_socket(struct fpm_worker_pool_s *wp, struct sockaddr *sa, int socklen)
+{
+	int backlog = -1;
+	int flags = 1;
+	int sock;
+	mode_t saved_umask;
+
+	/* we have custom backlog value */
+	if (wp->config->listen_options) {
+		backlog = wp->config->listen_options->backlog;
+	}
+
+	sock = socket(sa->sa_family, SOCK_STREAM, 0);
+
+	if (0 > sock) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "socket() failed");
+		return -1;
+	}
+
+	setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &flags, sizeof(flags));
+
+	if (wp->listen_address_domain == FPM_AF_UNIX) {
+		unlink( ((struct sockaddr_un *) sa)->sun_path);
+	}
+
+	saved_umask = umask(0777 ^ wp->socket_mode);
+
+	if (0 > bind(sock, sa, socklen)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "bind() for address '%s' failed", wp->config->listen_address);
+		return -1;
+	}
+
+	if (wp->listen_address_domain == FPM_AF_UNIX) {
+
+		char *path = ((struct sockaddr_un *) sa)->sun_path;
+
+		if (wp->socket_uid != -1 || wp->socket_gid != -1) {
+
+			if (0 > chown(path, wp->socket_uid, wp->socket_gid)) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "chown() for address '%s' failed", wp->config->listen_address);
+				return -1;
+			}
+
+		}
+
+	}
+
+	umask(saved_umask);
+
+	if (0 > listen(sock, backlog)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "listen() for address '%s' failed", wp->config->listen_address);
+		return -1;
+	}
+
+	return sock;
+}
+
+static int fpm_sockets_get_listening_socket(struct fpm_worker_pool_s *wp, struct sockaddr *sa, int socklen)
+{
+	int sock;
+
+	sock = fpm_sockets_hash_op(0, sa, 0, wp->listen_address_domain, FPM_GET_USE_SOCKET);
+
+	if (sock >= 0) return sock;
+
+	sock = fpm_sockets_new_listening_socket(wp, sa, socklen);
+
+	fpm_sockets_hash_op(sock, sa, 0, wp->listen_address_domain, FPM_STORE_USE_SOCKET);
+
+	return sock;
+}
+
+enum fpm_address_domain fpm_sockets_domain_from_address(char *address)
+{
+	if (strchr(address, ':')) return FPM_AF_INET;
+
+	if (strlen(address) == strspn(address, "0123456789")) return FPM_AF_INET;
+
+	return FPM_AF_UNIX;
+}
+
+static int fpm_socket_af_inet_listening_socket(struct fpm_worker_pool_s *wp)
+{
+	struct sockaddr_in sa_in;
+	char *dup_address = strdup(wp->config->listen_address);
+	char *port_str = strchr(dup_address, ':');
+	char *addr = NULL;
+	int port = 0;
+
+	if (port_str) { /* this is host:port pair */
+		*port_str++ = '\0';
+		port = atoi(port_str);
+		addr = dup_address;
+	}
+	else if (strlen(dup_address) == strspn(dup_address, "0123456789")) { /* this is port */
+		port = atoi(dup_address);
+		port_str = dup_address;
+	}
+
+	if (port == 0) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "invalid port value '%s'", port_str);
+		return -1;
+	}
+
+	memset(&sa_in, 0, sizeof(sa_in));
+
+	if (addr) {
+
+		sa_in.sin_addr.s_addr = inet_addr(addr);
+
+		if (sa_in.sin_addr.s_addr == INADDR_NONE) { /* do resolve */
+			if (0 > fpm_sockets_resolve_af_inet(addr, NULL, &sa_in)) {
+				return -1;
+			}
+			zlog(ZLOG_STUFF, ZLOG_NOTICE, "address '%s' resolved as %u.%u.%u.%u", addr, IPQUAD(&sa_in.sin_addr));
+		}
+	}
+	else {
+
+		sa_in.sin_addr.s_addr = htonl(INADDR_ANY);
+
+	}
+
+	sa_in.sin_family = AF_INET;
+	sa_in.sin_port = htons(port);
+
+	free(dup_address);
+
+	return fpm_sockets_get_listening_socket(wp, (struct sockaddr *) &sa_in, sizeof(struct sockaddr_in));
+}
+
+static int fpm_socket_af_unix_listening_socket(struct fpm_worker_pool_s *wp)
+{
+	struct sockaddr_un sa_un;
+
+	memset(&sa_un, 0, sizeof(sa_un));
+
+	cpystrn(sa_un.sun_path, wp->config->listen_address, sizeof(sa_un.sun_path));
+	sa_un.sun_family = AF_UNIX;
+
+	return fpm_sockets_get_listening_socket(wp, (struct sockaddr *) &sa_un, sizeof(struct sockaddr_un));
+}
+
+int fpm_sockets_init_main()
+{
+	int i;
+	struct fpm_worker_pool_s *wp;
+	char *inherited = getenv("FPM_SOCKETS");
+	struct listening_socket_s *ls;
+
+	if (0 == fpm_array_init(&sockets_list, sizeof(struct listening_socket_s), 10)) {
+		return -1;
+	}
+
+	/* import inherited sockets */
+	while (inherited && *inherited) {
+		char *comma = strchr(inherited, ',');
+		int type, fd_no;
+		char *eq;
+
+		if (comma) *comma = '\0';
+
+		eq = strchr(inherited, '=');
+
+		if (eq) {
+			*eq = '\0';
+
+			fd_no = atoi(eq + 1);
+
+			type = fpm_sockets_domain_from_address(inherited);
+
+			zlog(ZLOG_STUFF, ZLOG_NOTICE, "using inherited socket fd=%d, \"%s\"", fd_no, inherited);
+
+			fpm_sockets_hash_op(fd_no, 0, inherited, type, FPM_STORE_SOCKET);
+		}
+
+		if (comma) inherited = comma + 1;
+		else inherited = 0;
+	}
+
+	/* create all required sockets */
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+
+		if (!wp->is_template) {
+
+			switch (wp->listen_address_domain) {
+
+				case FPM_AF_INET :
+
+					wp->listening_socket = fpm_socket_af_inet_listening_socket(wp);
+					break;
+
+				case FPM_AF_UNIX :
+
+					if (0 > fpm_unix_resolve_socket_premissions(wp)) {
+						return -1;
+					}
+
+					wp->listening_socket = fpm_socket_af_unix_listening_socket(wp);
+					break;
+
+			}
+
+			if (wp->listening_socket == -1) {
+				return -1;
+			}
+		}
+
+	}
+
+	/* close unused sockets that was inherited */
+	ls = sockets_list.data;
+
+	for (i = 0; i < sockets_list.used; ) {
+
+		if (ls->refcount == 0) {
+			close(ls->sock);
+			if (ls->type == FPM_AF_UNIX) {
+				unlink(ls->key);
+			}
+			free(ls->key);
+			fpm_array_item_remove(&sockets_list, i);
+		}
+		else {
+			++i;
+			++ls;
+		}
+	}
+
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_sockets_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_sockets.h b/sapi/cgi/fpm/fpm_sockets.h
new file mode 100644
index 0000000..d5433e3
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_sockets.h
@@ -0,0 +1,37 @@
+
+	/* $Id: fpm_sockets.h,v 1.12 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_MISC_H
+#define FPM_MISC_H 1
+
+#include <unistd.h>
+#include <fcntl.h>
+
+#include "fpm_worker_pool.h"
+
+enum fpm_address_domain fpm_sockets_domain_from_address(char *addr);
+int fpm_sockets_init_main();
+
+
+static inline int fd_set_blocked(int fd, int blocked)
+{
+	int flags = fcntl(fd, F_GETFL);
+
+	if (flags < 0) return -1;
+
+	if (blocked)
+		flags &= ~O_NONBLOCK;
+	else
+		flags |= O_NONBLOCK;
+
+	return fcntl(fd, F_SETFL, flags);
+}
+
+#define IPQUAD(sin_addr) \
+			(unsigned int) ((unsigned char *) &(sin_addr)->s_addr)[0], \
+			(unsigned int) ((unsigned char *) &(sin_addr)->s_addr)[1], \
+			(unsigned int) ((unsigned char *) &(sin_addr)->s_addr)[2], \
+			(unsigned int) ((unsigned char *) &(sin_addr)->s_addr)[3]
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_stdio.c b/sapi/cgi/fpm/fpm_stdio.c
new file mode 100644
index 0000000..a6818d7
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_stdio.c
@@ -0,0 +1,286 @@
+
+	/* $Id: fpm_stdio.c,v 1.22.2.2 2008/12/13 03:32:24 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/types.h>
+#include <sys/stat.h>
+#include <string.h>
+#include <fcntl.h>
+#include <unistd.h>
+#include <errno.h>
+
+#include "fpm.h"
+#include "fpm_children.h"
+#include "fpm_events.h"
+#include "fpm_sockets.h"
+#include "fpm_stdio.h"
+#include "zlog.h"
+
+static int fd_stdout[2];
+static int fd_stderr[2];
+
+int fpm_stdio_init_main()
+{
+	int fd = open("/dev/null", O_RDWR);
+
+	if (0 > fd) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "open(\"/dev/null\") failed");
+		return -1;
+	}
+
+	if (0 > dup2(fd, STDIN_FILENO) || 0 > dup2(fd, STDOUT_FILENO)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "dup2() failed");
+		return -1;
+	}
+
+	close(fd);
+
+	return 0;
+}
+
+int fpm_stdio_init_final()
+{
+	if (fpm_global_config.daemonize) {
+
+		if (fpm_globals.error_log_fd != STDERR_FILENO) {
+			/* there might be messages to stderr from libevent, we need to log them all */
+			if (0 > dup2(fpm_globals.error_log_fd, STDERR_FILENO)) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "dup2() failed");
+				return -1;
+			}
+		}
+
+		zlog_set_level(fpm_globals.log_level);
+
+		zlog_set_fd(fpm_globals.error_log_fd);
+	}
+
+	return 0;
+}
+
+int fpm_stdio_init_child(struct fpm_worker_pool_s *wp)
+{
+	close(fpm_globals.error_log_fd);
+	fpm_globals.error_log_fd = -1;
+	zlog_set_fd(-1);
+
+	if (wp->listening_socket != STDIN_FILENO) {
+		if (0 > dup2(wp->listening_socket, STDIN_FILENO)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "dup2() failed");
+			return -1;
+		}
+	}
+
+	return 0;
+}
+
+static void fpm_stdio_child_said(int fd, short which, void *arg)
+{
+	static const int max_buf_size = 1024;
+	char buf[max_buf_size];
+	struct fpm_child_s *child = arg;
+	int is_stdout = fd == child->fd_stdout;
+	struct event *ev = is_stdout ? &child->ev_stdout : &child->ev_stderr;
+	int fifo_in = 1, fifo_out = 1;
+	int is_last_message = 0;
+	int in_buf = 0;
+	int res;
+
+#if 0
+	zlog(ZLOG_STUFF, ZLOG_DEBUG, "child %d said %s", (int) child->pid, is_stdout ? "stdout" : "stderr");
+#endif
+
+	while (fifo_in || fifo_out) {
+
+		if (fifo_in) {
+
+			res = read(fd, buf + in_buf, max_buf_size - 1 - in_buf);
+
+			if (res <= 0) { /* no data */
+				fifo_in = 0;
+
+				if (res < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
+					/* just no more data ready */
+				}
+				else { /* error or pipe is closed */
+
+					if (res < 0) { /* error */
+						zlog(ZLOG_STUFF, ZLOG_SYSERROR, "read() failed");
+					}
+
+					fpm_event_del(ev);
+					is_last_message = 1;
+
+					if (is_stdout) {
+						close(child->fd_stdout);
+						child->fd_stdout = -1;
+					}
+					else {
+						close(child->fd_stderr);
+						child->fd_stderr = -1;
+					}
+
+#if 0
+					if (in_buf == 0 && !fpm_globals.is_child) {
+						zlog(ZLOG_STUFF, ZLOG_DEBUG, "child %d (pool %s) %s pipe is closed", (int) child->pid,
+							child->wp->config->name, is_stdout ? "stdout" : "stderr");
+					}
+#endif
+				}
+			}
+			else {
+				in_buf += res;
+			}
+		}
+
+		if (fifo_out) {
+			if (in_buf == 0) {
+				fifo_out = 0;
+			}
+			else {
+				char *nl;
+				int should_print = 0;
+				buf[in_buf] = '\0';
+
+				/* FIXME: there might be binary data */
+
+				/* we should print if no more space in the buffer */
+				if (in_buf == max_buf_size - 1) {
+					should_print = 1;
+				}
+
+				/* we should print if no more data to come */
+				if (!fifo_in) {
+					should_print = 1;
+				}
+
+				nl = strchr(buf, '\n');
+
+				if (nl || should_print) {
+
+					if (nl) {
+						*nl = '\0';
+					}
+
+					zlog(ZLOG_STUFF, ZLOG_WARNING, "child %d (pool %s) said into %s: \"%s\"%s", (int) child->pid,
+						child->wp->config->name, is_stdout ? "stdout" : "stderr", buf, is_last_message ? ", pipe is closed" : "");
+
+					if (nl) {
+						int out_buf = 1 + nl - buf;
+						memmove(buf, buf + out_buf, in_buf - out_buf);
+						in_buf -= out_buf;
+					}
+					else {
+						in_buf = 0;
+					}
+				}
+			}
+		}
+	}
+
+}
+
+int fpm_stdio_prepare_pipes(struct fpm_child_s *child)
+{
+	if (0 == child->wp->config->catch_workers_output) { /* not required */
+		return 0;
+	}
+
+	if (0 > pipe(fd_stdout)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "pipe() failed");
+		return -1;
+	}
+
+	if (0 > pipe(fd_stderr)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "pipe() failed");
+		close(fd_stdout[0]); close(fd_stdout[1]);
+		return -1;
+	}
+
+	if (0 > fd_set_blocked(fd_stdout[0], 0) || 0 > fd_set_blocked(fd_stderr[0], 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fd_set_blocked() failed");
+		close(fd_stdout[0]); close(fd_stdout[1]);
+		close(fd_stderr[0]); close(fd_stderr[1]);
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_stdio_parent_use_pipes(struct fpm_child_s *child)
+{
+	if (0 == child->wp->config->catch_workers_output) { /* not required */
+		return 0;
+	}
+
+	close(fd_stdout[1]);
+	close(fd_stderr[1]);
+
+	child->fd_stdout = fd_stdout[0];
+	child->fd_stderr = fd_stderr[0];
+
+	fpm_event_add(child->fd_stdout, &child->ev_stdout, fpm_stdio_child_said, child);
+	fpm_event_add(child->fd_stderr, &child->ev_stderr, fpm_stdio_child_said, child);
+
+	return 0;
+}
+
+int fpm_stdio_discard_pipes(struct fpm_child_s *child)
+{
+	if (0 == child->wp->config->catch_workers_output) { /* not required */
+		return 0;
+	}
+
+	close(fd_stdout[1]);
+	close(fd_stderr[1]);
+
+	close(fd_stdout[0]);
+	close(fd_stderr[0]);
+
+	return 0;
+}
+
+void fpm_stdio_child_use_pipes(struct fpm_child_s *child)
+{
+	if (child->wp->config->catch_workers_output) {
+		dup2(fd_stdout[1], STDOUT_FILENO);
+		dup2(fd_stderr[1], STDERR_FILENO);
+		close(fd_stdout[0]); close(fd_stdout[1]);
+		close(fd_stderr[0]); close(fd_stderr[1]);
+	}
+	else {
+		/* stdout of parent is always /dev/null */
+		dup2(STDOUT_FILENO, STDERR_FILENO);
+	}
+}	
+
+int fpm_stdio_open_error_log(int reopen)
+{
+	int fd;
+
+	fd = open(fpm_global_config.error_log, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR);
+
+	if (0 > fd) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "open(\"%s\") failed", fpm_global_config.error_log);
+		return -1;
+	}
+
+	if (reopen) {
+		if (fpm_global_config.daemonize) {
+			dup2(fd, STDERR_FILENO);
+		}
+
+		dup2(fd, fpm_globals.error_log_fd);
+		close(fd);
+		fd = fpm_globals.error_log_fd; /* for FD_CLOSEXEC to work */
+	}
+	else {
+		fpm_globals.error_log_fd = fd;
+	}
+
+	fcntl(fd, F_SETFD, fcntl(fd, F_GETFD) | FD_CLOEXEC);
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_stdio.h b/sapi/cgi/fpm/fpm_stdio.h
new file mode 100644
index 0000000..d3d61e4
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_stdio.h
@@ -0,0 +1,20 @@
+
+	/* $Id: fpm_stdio.h,v 1.9 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_STDIO_H
+#define FPM_STDIO_H 1
+
+#include "fpm_worker_pool.h"
+
+int fpm_stdio_init_main();
+int fpm_stdio_init_final();
+int fpm_stdio_init_child(struct fpm_worker_pool_s *wp);
+int fpm_stdio_prepare_pipes(struct fpm_child_s *child);
+void fpm_stdio_child_use_pipes(struct fpm_child_s *child);
+int fpm_stdio_parent_use_pipes(struct fpm_child_s *child);
+int fpm_stdio_discard_pipes(struct fpm_child_s *child);
+int fpm_stdio_open_error_log(int reopen);
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_str.h b/sapi/cgi/fpm/fpm_str.h
new file mode 100644
index 0000000..19e2055
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_str.h
@@ -0,0 +1,49 @@
+
+	/* $Id: fpm_str.h,v 1.3 2008/05/24 17:38:47 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_STR_H
+#define FPM_STR_H 1
+
+static inline char *cpystrn(char *dst, const char *src, size_t dst_size)
+{
+	char *d, *end;
+	
+	if (!dst_size) return dst;
+	
+	d = dst;
+	end = dst + dst_size - 1;
+	
+	for (; d < end; ++d, ++src) {
+		if (!(*d = *src)) {
+			return d;
+		}
+	}
+
+	*d = '\0';
+
+	return d;
+}
+
+static inline char *str_purify_filename(char *dst, char *src, size_t size)
+{
+	char *d, *end;
+
+	d = dst;
+	end = dst + size - 1;
+
+	for (; d < end && *src; ++d, ++src) {
+		if (* (unsigned char *) src < ' ' || * (unsigned char *) src > '\x7f') {
+			*d = '.';
+		}
+		else {
+			*d = *src;
+		}
+	}
+
+	*d = '\0';
+
+	return d;
+}
+
+#endif
diff --git a/sapi/cgi/fpm/fpm_trace.c b/sapi/cgi/fpm/fpm_trace.c
new file mode 100644
index 0000000..7996355
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_trace.c
@@ -0,0 +1,46 @@
+
+	/* $Id: fpm_trace.c,v 1.1 2008/07/20 20:59:00 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/types.h>
+
+#include "fpm_trace.h"
+
+int fpm_trace_get_strz(char *buf, size_t sz, long addr)
+{
+	int i;
+	long l;
+	char *lc = (char *) &l;
+
+	if (0 > fpm_trace_get_long(addr, &l)) {
+		return -1;
+	}
+
+	i = l % SIZEOF_LONG;
+
+	l -= i;
+
+	for (addr = l; ; addr += SIZEOF_LONG) {
+
+		if (0 > fpm_trace_get_long(addr, &l)) {
+			return -1;
+		}
+
+		for ( ; i < SIZEOF_LONG; i++) {
+			--sz;
+
+			if (sz && lc[i]) {
+				*buf++ = lc[i];
+				continue;
+			}
+
+			*buf = '\0';
+			return 0;
+		}
+
+		i = 0;
+	}
+}
+
diff --git a/sapi/cgi/fpm/fpm_trace.h b/sapi/cgi/fpm/fpm_trace.h
new file mode 100644
index 0000000..b421172
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_trace.h
@@ -0,0 +1,17 @@
+
+	/* $Id: fpm_trace.h,v 1.3 2008/07/20 22:43:39 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_TRACE_H
+#define FPM_TRACE_H 1
+
+#include <unistd.h>
+
+int fpm_trace_signal(pid_t pid);
+int fpm_trace_ready(pid_t pid);
+int fpm_trace_close(pid_t pid);
+int fpm_trace_get_long(long addr, long *data);
+int fpm_trace_get_strz(char *buf, size_t sz, long addr);
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_trace_mach.c b/sapi/cgi/fpm/fpm_trace_mach.c
new file mode 100644
index 0000000..11cb9cf
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_trace_mach.c
@@ -0,0 +1,102 @@
+
+	/* $Id: fpm_trace_mach.c,v 1.4 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <mach/mach.h>
+#include <mach/mach_vm.h>
+
+#include <unistd.h>
+
+#include "fpm_trace.h"
+#include "fpm_process_ctl.h"
+#include "fpm_unix.h"
+#include "zlog.h"
+
+
+static mach_port_name_t target;
+static vm_offset_t target_page_base;
+static vm_offset_t local_page;
+static mach_msg_type_number_t local_size;
+
+static void fpm_mach_vm_deallocate()
+{
+	if (local_page) {
+		mach_vm_deallocate(mach_task_self(), local_page, local_size);
+		target_page_base = 0;
+		local_page = 0;
+		local_size = 0;
+	}
+}
+
+static int fpm_mach_vm_read_page(vm_offset_t page)
+{
+	kern_return_t kr;
+
+	kr = mach_vm_read(target, page, fpm_pagesize, &local_page, &local_size);
+
+	if (kr != KERN_SUCCESS) {
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "mach_vm_read() failed: %s (%d)", mach_error_string(kr), kr);
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_signal(pid_t pid)
+{
+	if (0 > fpm_pctl_kill(pid, FPM_PCTL_STOP)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "kill(SIGSTOP) failed");
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_ready(pid_t pid)
+{
+	kern_return_t kr;
+
+	kr = task_for_pid(mach_task_self(), pid, &target);
+
+	if (kr != KERN_SUCCESS) {
+		char *msg = "";
+
+		if (kr == KERN_FAILURE) {
+			msg = " It seems that master process does not have enough privileges to trace processes.";
+		}
+
+		zlog(ZLOG_STUFF, ZLOG_ERROR, "task_for_pid() failed: %s (%d)%s", mach_error_string(kr), kr, msg);
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_close(pid_t pid)
+{
+	fpm_mach_vm_deallocate();
+
+	target = 0;
+
+	return 0;
+}
+
+int fpm_trace_get_long(long addr, long *data)
+{
+	size_t offset = ((uintptr_t) (addr) % fpm_pagesize);
+	vm_offset_t base = (uintptr_t) (addr) - offset;
+
+	if (base != target_page_base) {
+		fpm_mach_vm_deallocate();
+		if (0 > fpm_mach_vm_read_page(base)) {
+			return -1;
+		}
+	}
+
+	*data = * (long *) (local_page + offset);
+
+	return 0;
+}
+
diff --git a/sapi/cgi/fpm/fpm_trace_pread.c b/sapi/cgi/fpm/fpm_trace_pread.c
new file mode 100644
index 0000000..f41bb91
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_trace_pread.c
@@ -0,0 +1,67 @@
+
+	/* $Id: fpm_trace_pread.c,v 1.7 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#define _GNU_SOURCE
+#define _FILE_OFFSET_BITS 64
+
+#include "fpm_config.h"
+
+#include <unistd.h>
+
+#include <fcntl.h>
+#include <stdio.h>
+#include <stdint.h>
+
+#include "fpm_trace.h"
+#include "fpm_process_ctl.h"
+#include "zlog.h"
+
+
+static int mem_file = -1;
+
+int fpm_trace_signal(pid_t pid)
+{
+	if (0 > fpm_pctl_kill(pid, FPM_PCTL_STOP)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "kill(SIGSTOP) failed");
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_ready(pid_t pid)
+{
+	char buf[128];
+
+	sprintf(buf, "/proc/%d/" PROC_MEM_FILE, (int) pid);
+
+	mem_file = open(buf, O_RDONLY);
+
+	if (0 > mem_file) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "open(%s) failed", buf);
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_close(pid_t pid)
+{
+	close(mem_file);
+
+	mem_file = -1;
+
+	return 0;
+}
+
+int fpm_trace_get_long(long addr, long *data)
+{
+	if (sizeof(*data) != pread(mem_file, (void *) data, sizeof(*data), (uintptr_t) addr)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "pread() failed");
+		return -1;
+	}
+
+	return 0;
+}
+
diff --git a/sapi/cgi/fpm/fpm_trace_ptrace.c b/sapi/cgi/fpm/fpm_trace_ptrace.c
new file mode 100644
index 0000000..11e2081
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_trace_ptrace.c
@@ -0,0 +1,85 @@
+
+	/* $Id: fpm_trace_ptrace.c,v 1.7 2008/09/18 23:34:11 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <sys/wait.h>
+#include <sys/ptrace.h>
+#include <unistd.h>
+#include <errno.h>
+
+#if defined(PT_ATTACH) && !defined(PTRACE_ATTACH)
+#define PTRACE_ATTACH PT_ATTACH
+#endif
+
+#if defined(PT_DETACH) && !defined(PTRACE_DETACH)
+#define PTRACE_DETACH PT_DETACH
+#endif
+
+#if defined(PT_READ_D) && !defined(PTRACE_PEEKDATA)
+#define PTRACE_PEEKDATA PT_READ_D
+#endif
+
+#include "fpm_trace.h"
+#include "zlog.h"
+
+static pid_t traced_pid;
+
+int fpm_trace_signal(pid_t pid)
+{
+	if (0 > ptrace(PTRACE_ATTACH, pid, 0, 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "ptrace(ATTACH) failed");
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_trace_ready(pid_t pid)
+{
+	traced_pid = pid;
+
+	return 0;
+}
+
+int fpm_trace_close(pid_t pid)
+{
+	if (0 > ptrace(PTRACE_DETACH, pid, (void *) 1, 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "ptrace(DETACH) failed");
+		return -1;
+	}
+
+	traced_pid = 0;
+
+	return 0;
+}
+
+int fpm_trace_get_long(long addr, long *data)
+{
+#ifdef PT_IO
+	struct ptrace_io_desc ptio = {
+		.piod_op = PIOD_READ_D,
+		.piod_offs = (void *) addr,
+		.piod_addr = (void *) data,
+		.piod_len = sizeof(long)
+	};
+
+	if (0 > ptrace(PT_IO, traced_pid, (void *) &ptio, 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "ptrace(PT_IO) failed");
+		return -1;
+	}
+#else
+	errno = 0;
+
+	*data = ptrace(PTRACE_PEEKDATA, traced_pid, (void *) addr, 0);
+
+	if (errno) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "ptrace(PEEKDATA) failed");
+		return -1;
+	}
+#endif
+
+	return 0;
+}
+
diff --git a/sapi/cgi/fpm/fpm_unix.c b/sapi/cgi/fpm/fpm_unix.c
new file mode 100644
index 0000000..4d5eecc
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_unix.c
@@ -0,0 +1,289 @@
+
+	/* $Id: fpm_unix.c,v 1.25.2.1 2008/12/13 03:18:23 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <string.h>
+#include <sys/time.h>
+#include <sys/resource.h>
+#include <stdlib.h>
+#include <unistd.h>
+#include <sys/types.h>
+#include <pwd.h>
+#include <grp.h>
+
+#ifdef HAVE_PRCTL
+#include <sys/prctl.h>
+#endif
+
+#include "fpm.h"
+#include "fpm_conf.h"
+#include "fpm_cleanup.h"
+#include "fpm_clock.h"
+#include "fpm_stdio.h"
+#include "fpm_unix.h"
+#include "zlog.h"
+
+size_t fpm_pagesize;
+
+int fpm_unix_resolve_socket_premissions(struct fpm_worker_pool_s *wp)
+{
+	struct fpm_listen_options_s *lo = wp->config->listen_options;
+
+	/* uninitialized */
+	wp->socket_uid = -1;
+	wp->socket_gid = -1;
+	wp->socket_mode = 0666;
+
+	if (!lo) return 0;
+
+	if (lo->owner && *lo->owner) {
+		struct passwd *pwd;
+
+		pwd = getpwnam(lo->owner);
+
+		if (!pwd) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "cannot get uid for user '%s', pool '%s'", lo->owner, wp->config->name);
+			return -1;
+		}
+
+		wp->socket_uid = pwd->pw_uid;
+		wp->socket_gid = pwd->pw_gid;
+	}
+
+	if (lo->group && *lo->group) {
+		struct group *grp;
+
+		grp = getgrnam(lo->group);
+
+		if (!grp) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "cannot get gid for group '%s', pool '%s'", lo->group, wp->config->name);
+			return -1;
+		}
+
+		wp->socket_gid = grp->gr_gid;
+	}
+
+	if (lo->mode && *lo->mode) {
+		wp->socket_mode = strtoul(lo->mode, 0, 8);
+	}
+
+	return 0;
+}
+
+static int fpm_unix_conf_wp(struct fpm_worker_pool_s *wp)
+{
+	int is_root = !geteuid();
+
+	if (is_root) {
+		if (wp->config->user && *wp->config->user) {
+
+			if (strlen(wp->config->user) == strspn(wp->config->user, "0123456789")) {
+				wp->set_uid = strtoul(wp->config->user, 0, 10);
+			}
+			else {
+				struct passwd *pwd;
+
+				pwd = getpwnam(wp->config->user);
+
+				if (!pwd) {
+					zlog(ZLOG_STUFF, ZLOG_ERROR, "cannot get uid for user '%s', pool '%s'", wp->config->user, wp->config->name);
+					return -1;
+				}
+
+				wp->set_uid = pwd->pw_uid;
+				wp->set_gid = pwd->pw_gid;
+
+				wp->user = strdup(pwd->pw_name);
+				wp->home = strdup(pwd->pw_dir);
+			}
+		}
+
+		if (wp->config->group && *wp->config->group) {
+
+			if (strlen(wp->config->group) == strspn(wp->config->group, "0123456789")) {
+				wp->set_gid = strtoul(wp->config->group, 0, 10);
+			}
+			else {
+				struct group *grp;
+
+				grp = getgrnam(wp->config->group);
+
+				if (!grp) {
+					zlog(ZLOG_STUFF, ZLOG_ERROR, "cannot get gid for group '%s', pool '%s'", wp->config->group, wp->config->name);
+					return -1;
+				}
+
+				wp->set_gid = grp->gr_gid;
+			}
+		}
+
+#ifndef I_REALLY_WANT_ROOT_PHP
+		if (wp->set_uid == 0 || wp->set_gid == 0) {
+			zlog(ZLOG_STUFF, ZLOG_ERROR, "please specify user and group other than root, pool '%s'", wp->config->name);
+			return -1;
+		}
+#endif
+	}
+	else { /* not root */
+		if (wp->config->user && *wp->config->user) {
+			zlog(ZLOG_STUFF, ZLOG_WARNING, "'user' directive is ignored, pool '%s'", wp->config->name);
+		}
+		if (wp->config->group && *wp->config->group) {
+			zlog(ZLOG_STUFF, ZLOG_WARNING, "'group' directive is ignored, pool '%s'", wp->config->name);
+		}
+		if (wp->config->chroot && *wp->config->chroot) {
+			zlog(ZLOG_STUFF, ZLOG_WARNING, "'chroot' directive is ignored, pool '%s'", wp->config->name);
+		}
+
+		{ /* set up HOME and USER anyway */
+			struct passwd *pwd;
+
+			pwd = getpwuid(getuid());
+
+			if (pwd) {
+				wp->user = strdup(pwd->pw_name);
+				wp->home = strdup(pwd->pw_dir);
+			}
+		}
+	}
+
+	return 0;
+}
+
+int fpm_unix_init_child(struct fpm_worker_pool_s *wp)
+{
+	int is_root = !geteuid();
+	int made_chroot = 0;
+
+	if (wp->config->rlimit_files) {
+		struct rlimit r;
+
+		getrlimit(RLIMIT_NOFILE, &r);
+
+		r.rlim_cur = (rlim_t) wp->config->rlimit_files;
+       r.rlim_max = r.rlim_cur;    
+		if (0 > setrlimit(RLIMIT_NOFILE, &r)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "setrlimit(RLIMIT_NOFILE) failed");
+		}
+	}
+
+	if (wp->config->rlimit_core) {
+		struct rlimit r;
+
+		getrlimit(RLIMIT_CORE, &r);
+
+		r.rlim_cur = wp->config->rlimit_core == -1 ? (rlim_t) RLIM_INFINITY : (rlim_t) wp->config->rlimit_core;
+       r.rlim_max = r.rlim_cur;
+		if (0 > setrlimit(RLIMIT_CORE, &r)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "setrlimit(RLIMIT_CORE) failed");
+		}
+	}
+
+	if (is_root && wp->config->chroot && *wp->config->chroot) {
+		if (0 > chroot(wp->config->chroot)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "chroot(%s) failed", wp->config->chroot);
+			return -1;
+		}
+		made_chroot = 1;
+	}
+
+	if (wp->config->chdir && *wp->config->chdir) {
+		if (0 > chdir(wp->config->chdir)) {
+			zlog(ZLOG_STUFF, ZLOG_SYSERROR, "chdir(%s) failed", wp->config->chdir);
+			return -1;
+		}
+	}
+	else if (made_chroot) {
+		chdir("/");
+	}
+
+	if (is_root) {
+		if (wp->set_gid) {
+			if (0 > setgid(wp->set_gid)) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "setgid(%d) failed", wp->set_gid);
+				return -1;
+			}
+		}
+		if (wp->set_uid) {
+			if (0 > initgroups(wp->config->user, wp->set_gid)) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "initgroups(%s, %d) failed", wp->config->user, wp->set_gid);
+				return -1;
+			}
+			if (0 > setuid(wp->set_uid)) {
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "setuid(%d) failed", wp->set_uid);
+				return -1;
+			}
+		}
+	}
+
+#ifdef HAVE_PRCTL
+	if (0 > prctl(PR_SET_DUMPABLE, 1, 0, 0, 0)) {
+		zlog(ZLOG_STUFF, ZLOG_SYSERROR, "prctl(PR_SET_DUMPABLE) failed");
+	}
+#endif
+
+	if (0 > fpm_clock_init()) {
+		return -1;
+	}
+
+	return 0;
+}
+
+int fpm_unix_init_main()
+{
+	struct fpm_worker_pool_s *wp;
+
+	fpm_pagesize = getpagesize();
+
+	if (fpm_global_config.daemonize) {
+
+		switch (fork()) {
+
+			case -1 :
+
+				zlog(ZLOG_STUFF, ZLOG_SYSERROR, "fork() failed");
+				return -1;
+
+			case 0 :
+
+				break;
+
+			default :
+
+				fpm_cleanups_run(FPM_CLEANUP_PARENT_EXIT);
+				exit(0);
+
+		}
+
+	}
+
+	setsid();
+
+	if (0 > fpm_clock_init()) {
+		return -1;
+	}
+
+	fpm_globals.parent_pid = getpid();
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp->next) {
+
+		if (0 > fpm_unix_conf_wp(wp)) {
+			return -1;
+		}
+
+	}
+
+	fpm_stdio_init_final();
+
+	{
+		struct rlimit r;
+		getrlimit(RLIMIT_NOFILE, &r);
+
+		zlog(ZLOG_STUFF, ZLOG_NOTICE, "getrlimit(nofile): max:%lld, cur:%lld",
+			(long long) r.rlim_max, (long long) r.rlim_cur);
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_unix.h b/sapi/cgi/fpm/fpm_unix.h
new file mode 100644
index 0000000..3451db1
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_unix.h
@@ -0,0 +1,17 @@
+
+	/* $Id: fpm_unix.h,v 1.8 2008/05/25 13:21:13 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_UNIX_H
+#define FPM_UNIX_H 1
+
+#include "fpm_worker_pool.h"
+
+int fpm_unix_resolve_socket_premissions(struct fpm_worker_pool_s *wp);
+int fpm_unix_init_child(struct fpm_worker_pool_s *wp);
+int fpm_unix_init_main();
+
+extern size_t fpm_pagesize;
+
+#endif
+
diff --git a/sapi/cgi/fpm/fpm_worker_pool.c b/sapi/cgi/fpm/fpm_worker_pool.c
new file mode 100644
index 0000000..49dd5a8
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_worker_pool.c
@@ -0,0 +1,69 @@
+
+	/* $Id: fpm_worker_pool.c,v 1.15.2.1 2008/12/13 03:21:18 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <string.h>
+#include <stdlib.h>
+#include <unistd.h>
+
+#include "fpm_worker_pool.h"
+#include "fpm_cleanup.h"
+#include "fpm_children.h"
+#include "fpm_shm.h"
+#include "fpm_shm_slots.h"
+#include "fpm_conf.h"
+
+struct fpm_worker_pool_s *fpm_worker_all_pools;
+
+static void fpm_worker_pool_cleanup(int which, void *arg)
+{
+	struct fpm_worker_pool_s *wp, *wp_next;
+
+	for (wp = fpm_worker_all_pools; wp; wp = wp_next) {
+		wp_next = wp->next;
+		fpm_worker_pool_config_free(wp->config);
+		fpm_children_free(wp->children);
+		fpm_array_free(&wp->slots_used);
+		fpm_array_free(&wp->slots_free);
+		fpm_shm_free_list(wp->shm_list, which == FPM_CLEANUP_CHILD ? fpm_shm_slots_mem() : 0);
+		free(wp->config);
+		free(wp->user);
+		free(wp->home);
+		free(wp);
+	}
+
+	fpm_worker_all_pools = 0;
+}
+
+struct fpm_worker_pool_s *fpm_worker_pool_alloc()
+{
+	struct fpm_worker_pool_s *ret;
+
+	ret = malloc(sizeof(struct fpm_worker_pool_s));
+
+	if (!ret) {
+		return 0;
+	}
+
+	memset(ret, 0, sizeof(struct fpm_worker_pool_s));
+
+	if (!fpm_worker_all_pools) {
+		fpm_worker_all_pools = ret;
+	}
+
+	fpm_array_init(&ret->slots_used, sizeof(struct fpm_shm_slot_ptr_s), 50);
+	fpm_array_init(&ret->slots_free, sizeof(struct fpm_shm_slot_ptr_s), 50);
+
+	return ret;
+}
+
+int fpm_worker_pool_init_main()
+{
+	if (0 > fpm_cleanup_add(FPM_CLEANUP_ALL, fpm_worker_pool_cleanup, 0)) {
+		return -1;
+	}
+
+	return 0;
+}
diff --git a/sapi/cgi/fpm/fpm_worker_pool.h b/sapi/cgi/fpm/fpm_worker_pool.h
new file mode 100644
index 0000000..cc0dbbd
--- /dev/null
+++ b/sapi/cgi/fpm/fpm_worker_pool.h
@@ -0,0 +1,46 @@
+
+	/* $Id: fpm_worker_pool.h,v 1.13 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2007,2008 Andrei Nigmatulin */
+
+#ifndef FPM_WORKER_POOL_H
+#define FPM_WORKER_POOL_H 1
+
+#include "fpm_conf.h"
+#include "fpm_arrays.h"
+
+struct fpm_worker_pool_s;
+struct fpm_child_s;
+struct fpm_child_stat_s;
+struct fpm_shm_s;
+
+enum fpm_address_domain {
+	FPM_AF_UNIX = 1,
+	FPM_AF_INET = 2
+};
+
+struct fpm_worker_pool_s {
+	struct fpm_worker_pool_s *next;
+	struct fpm_worker_pool_config_s *config;
+	char *user, *home;									/* for setting env USER and HOME */
+	enum fpm_address_domain listen_address_domain;
+	int listening_socket;
+	int set_uid, set_gid;								/* config uid and gid */
+	unsigned is_template:1;									/* just config template, no processes will be created */
+	int socket_uid, socket_gid, socket_mode;
+
+	struct fpm_shm_s *shm_list;
+	struct fpm_array_s slots_used;
+	struct fpm_array_s slots_free;
+
+	/* runtime */
+	struct fpm_child_s *children;
+	int running_children;
+};
+
+struct fpm_worker_pool_s *fpm_worker_pool_alloc();
+int fpm_worker_pool_init_main();
+
+extern struct fpm_worker_pool_s *fpm_worker_all_pools;
+
+#endif
+
diff --git a/sapi/cgi/fpm/init.d/php-fpm.in b/sapi/cgi/fpm/init.d/php-fpm.in
new file mode 100644
index 0000000..0befa52
--- /dev/null
+++ b/sapi/cgi/fpm/init.d/php-fpm.in
@@ -0,0 +1,139 @@
+#! /bin/sh
+
+php_fpm_BIN=@prefix@/bin/php-cgi
+php_fpm_CONF=@php_fpm_conf_path@
+php_fpm_PID=@php_fpm_pid_path@
+
+
+php_opts="--fpm-config $php_fpm_CONF"
+
+
+wait_for_pid () {
+	try=0
+
+	while test $try -lt 35 ; do
+
+		case "$1" in
+			'created')
+			if [ -f "$2" ] ; then
+				try=''
+				break
+			fi
+			;;
+
+			'removed')
+			if [ ! -f "$2" ] ; then
+				try=''
+				break
+			fi
+			;;
+		esac
+
+		echo -n .
+		try=`expr $try + 1`
+		sleep 1
+
+	done
+
+}
+
+case "$1" in
+	start)
+		echo -n "Starting php_fpm "
+
+		$php_fpm_BIN --fpm $php_opts
+
+		if [ "$?" != 0 ] ; then
+			echo " failed"
+			exit 1
+		fi
+
+		wait_for_pid created $php_fpm_PID
+
+		if [ -n "$try" ] ; then
+			echo " failed"
+			exit 1
+		else
+			echo " done"
+		fi
+	;;
+
+	stop)
+		echo -n "Shutting down php_fpm "
+
+		if [ ! -r $php_fpm_PID ] ; then
+			echo "warning, no pid file found - php-fpm is not running ?"
+			exit 1
+		fi
+
+		kill -TERM `cat $php_fpm_PID`
+
+		wait_for_pid removed $php_fpm_PID
+
+		if [ -n "$try" ] ; then
+			echo " failed"
+			exit 1
+		else
+			echo " done"
+		fi
+	;;
+
+	quit)
+		echo -n "Gracefully shutting down php_fpm "
+
+		if [ ! -r $php_fpm_PID ] ; then
+			echo "warning, no pid file found - php-fpm is not running ?"
+			exit 1
+		fi
+
+		kill -QUIT `cat $php_fpm_PID`
+
+		wait_for_pid removed $php_fpm_PID
+
+		if [ -n "$try" ] ; then
+			echo " failed"
+			exit 1
+		else
+			echo " done"
+		fi
+	;;
+
+	restart)
+		$0 stop
+		$0 start
+	;;
+
+	reload)
+
+		echo -n "Reload service php-fpm "
+
+		if [ ! -r $php_fpm_PID ] ; then
+			echo "warning, no pid file found - php-fpm is not running ?"
+			exit 1
+		fi
+
+		kill -USR2 `cat $php_fpm_PID`
+
+		echo " done"
+	;;
+
+	logrotate)
+
+		echo -n "Re-opening php-fpm log file "
+
+		if [ ! -r $php_fpm_PID ] ; then
+			echo "warning, no pid file found - php-fpm is not running ?"
+			exit 1
+		fi
+
+		kill -USR1 `cat $php_fpm_PID`
+
+		echo " done"
+	;;
+
+	*)
+		echo "Usage: $0 {start|stop|quit|restart|reload|logrotate}"
+		exit 1
+	;;
+
+esac
diff --git a/sapi/cgi/fpm/xml_config.c b/sapi/cgi/fpm/xml_config.c
new file mode 100644
index 0000000..10eb77e
--- /dev/null
+++ b/sapi/cgi/fpm/xml_config.c
@@ -0,0 +1,278 @@
+
+	/* $Id: xml_config.c,v 1.9 2008/08/26 15:09:15 anight Exp $ */
+	/* (c) 2004-2007 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#ifdef HAVE_ALLOCA_H
+#include <alloca.h>
+#endif
+#include <string.h>
+#include <stdio.h>
+#include <stddef.h>
+#include <stdlib.h>
+
+#include <libxml/parser.h>
+#include <libxml/tree.h>
+
+#include "xml_config.h"
+
+static struct xml_conf_section **xml_conf_sections = 0;
+static int xml_conf_sections_allocated = 0;
+static int xml_conf_sections_used = 0;
+
+char *xml_conf_set_slot_boolean(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	long value_y = !strcasecmp(value, "yes") || !strcmp(value,  "1") || !strcasecmp(value, "on");
+	long value_n = !strcasecmp(value, "no")  || !strcmp(value,  "0") || !strcasecmp(value, "off");
+
+	if (!value_y && !value_n) {
+		return "xml_conf_set_slot(): invalid boolean value";
+	}
+
+#ifdef XML_CONF_DEBUG
+	fprintf(stderr, "setting boolean '%s' => %s\n", name, value_y ? "TRUE" : "FALSE");
+#endif
+
+	* (int *) ((char *) *conf + offset) = value_y ? 1 : 0;
+
+	return NULL;
+}
+
+char *xml_conf_set_slot_string(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	char *v = strdup(value);
+
+	if (!v) return "xml_conf_set_slot_string(): strdup() failed";
+
+#ifdef XML_CONF_DEBUG
+	fprintf(stderr, "setting string '%s' => '%s'\n", name, v);
+#endif
+
+	* (char **) ((char *) *conf + offset) = v;
+
+	return NULL;
+}
+
+char *xml_conf_set_slot_integer(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	int v = atoi(value);
+
+	* (int *) ((char *) *conf + offset) = v;
+
+#ifdef XML_CONF_DEBUG
+	fprintf(stderr, "setting integer '%s' => %d\n", name, v);
+#endif
+
+	return NULL;
+}
+
+char *xml_conf_set_slot_time(void **conf, char *name, void *vv, intptr_t offset)
+{
+	char *value = vv;
+	int len = strlen(value);
+	char suffix;
+	int seconds;
+
+	if (!len) return "xml_conf_set_slot_timeval(): invalid timeval value";
+
+	suffix = value[len-1];
+
+	value[len-1] = '\0';
+
+	switch (suffix) {
+		case 's' :
+			seconds = atoi(value);
+			break;
+		case 'm' :
+			seconds = 60 * atoi(value);
+			break;
+		case 'h' :
+			seconds = 60 * 60 * atoi(value);
+			break;
+		case 'd' :
+			seconds = 24 * 60 * 60 * atoi(value);
+			break;
+		default :
+			return "xml_conf_set_slot_timeval(): unknown suffix used in timeval value";
+	}
+
+	* (int *) ((char *) *conf + offset) = seconds;
+
+#ifdef XML_CONF_DEBUG
+	fprintf(stderr, "setting time '%s' => %d:%02d:%02d:%02d\n", name, expand_dhms(seconds));
+#endif
+
+	return NULL;
+}
+
+char *xml_conf_parse_section(void **conf, struct xml_conf_section *section, void *xml_node)
+{
+	xmlNode *element = xml_node;
+	char *ret = 0;
+
+#ifdef XML_CONF_DEBUG
+	fprintf(stderr, "processing a section %s\n", section->path);
+#endif
+
+	for ( ; element; element = element->next) {
+		if (element->type == XML_ELEMENT_NODE && !strcmp((const char *) element->name, "value") && element->children) {
+			xmlChar *name = xmlGetProp(element, (unsigned char *) "name");
+
+			if (name) {
+				int i;
+
+#ifdef XML_CONF_DEBUG
+				fprintf(stderr, "found a value: %s\n", name);
+#endif
+				for (i = 0; section->parsers[i].parser; i++) {
+					if (!section->parsers[i].name || !strcmp(section->parsers[i].name, (char *) name)) {
+						break;
+					}
+				}
+
+				if (section->parsers[i].parser) {
+					if (section->parsers[i].type == XML_CONF_SCALAR) {
+						if (element->children->type == XML_TEXT_NODE) {
+							ret = section->parsers[i].parser(conf, (char *) name, element->children->content, section->parsers[i].offset);
+						}
+						else {
+							ret = "XML_TEXT_NODE is expected, something different is given";
+						}
+					}
+					else {
+						ret = section->parsers[i].parser(conf, (char *) name, element->children, section->parsers[i].offset);
+					}
+
+					xmlFree(name);
+					if (ret) return ret;
+					else continue;
+				}
+
+				fprintf(stderr, "Warning, unknown setting '%s' in section '%s'\n", (char *) name, section->path);
+
+				xmlFree(name);
+			}
+		}
+	}
+
+	return NULL;
+}
+
+static char *xml_conf_parse_file(xmlNode *element)
+{
+	char *ret = 0;
+
+	for ( ; element; element = element->next) {
+
+		if (element->parent && element->type == XML_ELEMENT_NODE && !strcmp((const char *) element->name, "section")) {
+			xmlChar *name = xmlGetProp(element, (unsigned char *) "name");
+
+			if (name) {
+				char *parent_name = (char *) xmlGetNodePath(element->parent);
+				char *full_name;
+				int i;
+				struct xml_conf_section *section = NULL;
+
+#ifdef XML_CONF_DEBUG
+				fprintf(stderr, "got a section: %s/%s\n", parent_name, name);
+#endif
+				full_name = alloca(strlen(parent_name) + strlen((char *) name) + 1 + 1);
+
+				sprintf(full_name, "%s/%s", parent_name, (char *) name);
+
+				xmlFree(parent_name);
+				xmlFree(name);
+
+				for (i = 0; i < xml_conf_sections_used; i++) {
+					if (!strcmp(xml_conf_sections[i]->path, full_name)) {
+						section = xml_conf_sections[i];
+					}
+				}
+
+				if (section) { /* found a registered section */
+					void *conf = section->conf();
+					ret = xml_conf_parse_section(&conf, section, element->children);
+					if (ret) break;
+				}
+
+			}
+		}
+
+		if (element->children) {
+			ret = xml_conf_parse_file(element->children);
+			if (ret) break;
+		}
+	}
+
+	return ret;
+}
+
+char *xml_conf_load_file(char *file)
+{
+	char *ret = 0;
+	xmlDoc *doc;
+
+	LIBXML_TEST_VERSION
+
+	doc = xmlParseFile(file);
+
+	if (doc) {
+		ret = xml_conf_parse_file(doc->children);
+		xmlFreeDoc(doc);
+	}
+	else {
+		ret = "failed to parse conf file";
+	}
+
+	xmlCleanupParser();
+	return ret;
+}
+
+int xml_conf_init()
+{
+	return 0;
+}
+
+void xml_conf_clean()
+{
+	if (xml_conf_sections) {
+		free(xml_conf_sections);
+	}
+}
+
+int xml_conf_section_register(struct xml_conf_section *section)
+{
+	if (xml_conf_sections_allocated == xml_conf_sections_used) {
+		int new_size = xml_conf_sections_used + 10;
+		void *new_ptr = realloc(xml_conf_sections, sizeof(struct xml_conf_section *) * new_size);
+
+		if (new_ptr) {
+			xml_conf_sections = new_ptr;
+			xml_conf_sections_allocated = new_size;
+		}
+		else {
+			fprintf(stderr, "xml_conf_section_register(): out of memory\n");
+			return -1;
+		}
+	}
+
+	xml_conf_sections[xml_conf_sections_used++] = section;
+
+	return 0;
+}
+
+int xml_conf_sections_register(struct xml_conf_section *sections[])
+{
+	for ( ; sections && *sections; sections++) {
+		if (0 > xml_conf_section_register(*sections)) {
+			return -1;
+		}
+	}
+
+	return 0;
+}
+
diff --git a/sapi/cgi/fpm/xml_config.h b/sapi/cgi/fpm/xml_config.h
new file mode 100644
index 0000000..b6169cd
--- /dev/null
+++ b/sapi/cgi/fpm/xml_config.h
@@ -0,0 +1,43 @@
+
+	/* $Id: xml_config.h,v 1.3 2008/09/18 23:02:58 anight Exp $ */
+	/* (c) 2004-2007 Andrei Nigmatulin */
+
+#ifndef XML_CONFIG_H
+#define XML_CONFIG_H 1
+
+#include <stdint.h>
+
+struct xml_value_parser;
+
+struct xml_value_parser {
+	int type;
+	char *name;
+	char *(*parser)(void **, char *, void *, intptr_t offset);
+	intptr_t offset;
+};
+
+struct xml_conf_section {
+	void *(*conf)();
+	char *path;
+	struct xml_value_parser *parsers;
+};
+
+char *xml_conf_set_slot_boolean(void **conf, char *name, void *value, intptr_t offset);
+char *xml_conf_set_slot_string(void **conf, char *name, void *value, intptr_t offset);
+char *xml_conf_set_slot_integer(void **conf, char *name, void *value, intptr_t offset);
+char *xml_conf_set_slot_time(void **conf, char *name, void *value, intptr_t offset);
+
+int xml_conf_init();
+void xml_conf_clean();
+char *xml_conf_load_file(char *file);
+char *xml_conf_parse_section(void **conf, struct xml_conf_section *section, void *ve);
+int xml_conf_section_register(struct xml_conf_section *section);
+int xml_conf_sections_register(struct xml_conf_section *sections[]);
+
+#define expand_hms(value) (value) / 3600, ((value) % 3600) / 60, (value) % 60
+
+#define expand_dhms(value) (value) / 86400, ((value) % 86400) / 3600, ((value) % 3600) / 60, (value) % 60
+
+enum { XML_CONF_SCALAR = 1, XML_CONF_SUBSECTION = 2 };
+
+#endif
diff --git a/sapi/cgi/fpm/zlog.c b/sapi/cgi/fpm/zlog.c
new file mode 100644
index 0000000..2fb6c45
--- /dev/null
+++ b/sapi/cgi/fpm/zlog.c
@@ -0,0 +1,113 @@
+
+	/* $Id: zlog.c,v 1.7 2008/05/22 21:08:32 anight Exp $ */
+	/* (c) 2004-2007 Andrei Nigmatulin */
+
+#include "fpm_config.h"
+
+#include <stdio.h>
+#include <unistd.h>
+#include <time.h>
+#include <string.h>
+#include <stdarg.h>
+#include <sys/time.h>
+#include <errno.h>
+
+#include "zlog.h"
+
+#define MAX_LINE_LENGTH 1024
+
+static int zlog_fd = -1;
+static int zlog_level = ZLOG_NOTICE;
+
+static const char *level_names[] = {
+	[ZLOG_DEBUG]		= "DEBUG",
+	[ZLOG_NOTICE]		= "NOTICE",
+	[ZLOG_WARNING]		= "WARNING",
+	[ZLOG_ERROR]		= "ERROR",
+	[ZLOG_ALERT]		= "ALERT",
+};
+
+size_t zlog_print_time(struct timeval *tv, char *timebuf, size_t timebuf_len)
+{
+	struct tm t;
+	size_t len;
+
+	len = strftime(timebuf, timebuf_len, "%b %d %H:%M:%S", localtime_r((const time_t *) &tv->tv_sec, &t));
+	len += snprintf(timebuf + len, timebuf_len - len, ".%06d", (int) tv->tv_usec);
+
+	return len;
+}
+
+int zlog_set_fd(int new_fd)
+{
+	int old_fd = zlog_fd;
+	zlog_fd = new_fd;
+
+	return old_fd;
+}
+
+int zlog_set_level(int new_value)
+{
+	int old_value = zlog_level;
+
+	zlog_level = new_value;
+
+	return old_value;
+}
+
+void zlog(const char *function, int line, int flags, const char *fmt, ...)
+{
+	struct timeval tv;
+	char buf[MAX_LINE_LENGTH];
+	const size_t buf_size = MAX_LINE_LENGTH;
+	va_list args;
+	size_t len;
+	int truncated = 0;
+	int saved_errno;
+
+	if ((flags & ZLOG_LEVEL_MASK) < zlog_level) {
+		return;
+	}
+
+	saved_errno = errno;
+
+	gettimeofday(&tv, 0);
+
+	len = zlog_print_time(&tv, buf, buf_size);
+
+	len += snprintf(buf + len, buf_size - len, " [%s] %s(), line %d: ", level_names[flags & ZLOG_LEVEL_MASK], function, line);
+
+	if (len > buf_size - 1) {
+		truncated = 1;
+	}
+
+	if (!truncated) {
+		va_start(args, fmt);
+
+		len += vsnprintf(buf + len, buf_size - len, fmt, args);
+
+		va_end(args);
+
+		if (len >= buf_size) {
+			truncated = 1;
+		}
+	}
+
+	if (!truncated) {
+		if (flags & ZLOG_HAVE_ERRNO) {
+			len += snprintf(buf + len, buf_size - len, ": %s (%d)", strerror(saved_errno), saved_errno);
+			if (len >= buf_size) {
+				truncated = 1;
+			}
+		}
+	}
+
+	if (truncated) {
+		memcpy(buf + buf_size - sizeof("..."), "...", sizeof("...") - 1);
+		len = buf_size - 1;
+	}
+
+	buf[len++] = '\n';
+
+	write(zlog_fd > -1 ? zlog_fd : STDERR_FILENO, buf, len);
+}
diff --git a/sapi/cgi/fpm/zlog.h b/sapi/cgi/fpm/zlog.h
new file mode 100644
index 0000000..b5ac3d9
--- /dev/null
+++ b/sapi/cgi/fpm/zlog.h
@@ -0,0 +1,34 @@
+
+	/* $Id: zlog.h,v 1.7 2008/05/22 21:08:32 anight Exp $ */
+	/* (c) 2004-2007 Andrei Nigmatulin */
+
+#ifndef ZLOG_H
+#define ZLOG_H 1
+
+#define ZLOG_STUFF		__func__, __LINE__
+
+struct timeval;
+
+int zlog_set_fd(int new_fd);
+int zlog_set_level(int new_value);
+
+size_t zlog_print_time(struct timeval *tv, char *timebuf, size_t timebuf_len);
+
+void zlog(const char *function, int line, int flags, const char *fmt, ...)
+		__attribute__ ((format(printf,4,5)));
+
+enum {
+	ZLOG_DEBUG			= 1,
+	ZLOG_NOTICE			= 2,
+	ZLOG_WARNING		= 3,
+	ZLOG_ERROR			= 4,
+	ZLOG_ALERT			= 5,
+};
+
+#define ZLOG_LEVEL_MASK 7
+
+#define ZLOG_HAVE_ERRNO 0x100
+
+#define ZLOG_SYSERROR (ZLOG_ERROR | ZLOG_HAVE_ERRNO)
+
+#endif
