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
    #if($content =~ /http:\\\/\\\/s\.ytimg\.com\\\/yts\\\/swfbin\\\/watch_(.+?)\.swf/) {
    if($content =~  /http:\\\/\\\/s\.ytimg\.com\\\/yts\\\/jsbin\\\/html5player-(\w+?)\.js/) {
        $text = $1;
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
        print "test\n";
        save_version $version;
        parse_template $code,$version;
    }

    
}

main;

