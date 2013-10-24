@echo off

set DA_PATH=E:\vstfbing\Multimedia\DA
REM ==== Find Visual Studio 2012 (11.0) installation dir ====
set TF_EXE=
for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE for /f "tokens=1,2,*" %%a in ('reg.exe QUERY HKLM\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\11.0 /v InstallDir') do set TF_EXE=%%c
if not defined TF_EXE goto :err_novs
set TF_EXE=%TF_EXE%\
set TF_EXE=%TF_EXE:\\=\%
if not exist "%TF_EXE%tf.exe" goto :err_notf
set TF_EXE=%TF_EXE%tf.exe
echo %TF_EXE%

REM ==== Copy YT leatest template ====
set TEMPLATE_PATH=E:\vstfbing\Multimedia\DA\autoYT\templates\MMVideo_youtube.com_youtube-watch(template).xml
copy %TEMPLATE_PATH% "templates\MMVideo_youtube.com_youtube-watch(template).xml"
attrib -R "templates\MMVideo_youtube.com_youtube-watch(template).xml"


REM ==== Generate and check in youtube model if version have changed ====
set model_file="MMVideo_youtube.com_youtube-watch(template).xml"
if exist %model_file% (
    del %model_file% /f /q
)
perl -w -x "%~f0"

set prod_model_file="%DA_PATH%\ProdModels\youtube.com\watch\%model_file:"=%"
set version_file="version.txt"
if exist %model_file% (
    "%TF_EXE%" get %prod_model_file% /overwrite
    fc %model_file% %prod_model_file% > nul
    if %errorlevel% == 0 goto :EOF
    "%TF_EXE%" checkout %prod_model_file%
    copy  %model_file% %prod_model_file%
    "%TF_EXE%" checkin %prod_model_file% /comment:"auto update signature" /override:"auto update signature" /notes:"Code Reviewer"="me" /noprompt
)


goto :EOF

REM ==== Error message ====
:err_novs
echo Cannot find Visual Studio 2012 installation
goto :EOF

:err_notf
echo tf.exe is not found in Visual Studio 2012 installation: %TF_EXE%
goto :EOF


#!perl
sub parse_template {
    
    $CODE = shift;
    $VERSION = shift;
    $file = 'templates\MMVideo_youtube.com_youtube-watch(template).xml';
    $target = 'MMVideo_youtube.com_youtube-watch(template).xml';

    local $/ = undef;
    open($fd, "<", $file) or die "cannot open $file: $!";
    binmode $fd;
    $CONTENT = <$fd>;
    close $fd;

    $CONTENT =~ s/\/\/{{code}}/$CODE/;
    $CONTENT =~ s/{{version}}/$VERSION/;

    open($wfd, ">", $target) or die "cannot open file $target: $!";
    binmode $wfd;
    print $wfd $CONTENT;
    close $wfd;
}

sub download_content {
    $url = "http://www.youtube.com/watch?v=AYFD18BwmJ4";
    $content = `wget -q "$url" -O -`;
    return $content;
}



sub get_code {
    $content = shift;
    $text = "";
    if($content =~ /(http:\\\/\\\/s\.ytimg\.com\\\/yts\\\/jsbin\\\/html5player-\w+\.js)/) {
        
        $jsurl = $1;
        $jsurl =~ s/\\//g;

        $js = `wget -q "$jsurl" -O -`;

        $js =~ /\w+\.signature=(\w+)\(\w+\)/;
        $func = $1;

        $js =~ /function $func\((\w+)\)\{(.*?)\}/;
        $var = $1;
        $code = $2;
        
        @statements = split(/;/,$code);
        
        foreach $temp (@statements) {
            print "$temp\n";
            if($temp =~ /$var\.reverse\(\)/) {
                $text = $text."szSign = reverse_1586(szSign);\r\n";
            }
            elsif($temp =~ /$var\.slice\((\d+)\)/) {
                $num = $1;
                $text = $text."szSign = clone_1586(szSign, $num);\r\n";
            }
            elsif($temp =~ /\w+=\w+\(.+?(\d+)\)/) {
                $num = $1;
                $text = $text."szSign = swap_1586(szSign, $num);\r\n";
            }
        }
    } 
    return $text;
}

sub get_version {
    $content = shift;
    $text = "";
    if($content =~ /"url":\s*"(\S+\.swf)/) {
    #if($content =~  /http:\\\/\\\/s\.ytimg\.com\\\/yts\\\/jsbin\\\/html5player-(\w+?)\.js/) {
        $text = $1;
        $text =~ s/\\//g;
    }

    print "version: $text\n";
    return $text;
}

sub save_version {
    $version = shift;
    $target = 'version.txt';
    open($wfd, ">", $target) or die "cannot open file $target: $!";
    binmode $wfd;
    print $wfd $version;
    close $wfd;
}

sub read_pre_version {
    $source = 'version.txt';
    open($fd, "<", $source) or die "cannot open file $source: $!";
    binmode $fd;
    my $version = <$fd>;
    close $fd;
    return $version;
}

sub main {

    $content = download_content;
    $code = get_code $content;
    $version = get_version $content;

    if(!$code || !$version)
    {
        return;
    }

    $preVersion = read_pre_version;
    print "ver: $version\n";
    print "pre: $preVersion\n";
    if($version ne $preVersion) {
        save_version $version;
        parse_template $code,$version;
    }

    
}

main;


