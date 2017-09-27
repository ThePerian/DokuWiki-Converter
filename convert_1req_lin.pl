#!/usr/bin/perl
use strict;
use warnings;

use HTML::WikiConverter;
use Encode qw(encode decode);
use File::Find;
use RPC::XML::Client;
use JSON;
use File::stat;
use Time::localtime;
use Cwd;
use utf8;

my $CURRENTDIR =  cwd();
my $CYRILLIC_WIDTH = 6;
my $NON_CYRILLIC_WIDTH = 1;
my $MAX_NAME_LENGTH = 255;

# get config
my $json = readFile('config.json');
my %param = %{decode_json($json)};

# get files to convert
my @files = getFileNames(%param);
my $files = @files;
die "no files found\n" if (!$files);
print "total $files files found, begin converting\n";

# connect to dokuwiki
my $client = wikiConnect( %param );

# get versions of rtf and doc files to determine
# whether we should convert them again
$json = readFile($param{'version'});
my %version = %{decode_json($json)};

# convert files
FILES:
for my $file (@files) {
  my $modified = getLastModifiedDate($file);
  next FILES if ($version{$file} eq $modified);
  my $originalfile = $file;
  
  # rtf -> html
  # recode to correctly show cyrillic
  print encode('windows-866', decode('windows-1251', "converting $file to html\n"));
  $param{'filename'} = $file;
  $file = rtf2html(%param);
  next FILES if (!$file);

  # html -> txt
  print encode('windows-866', decode('windows-1251', "done, converting $file to txt\n"));
  $param{'htmlstr'} = readFile($file);
  my $wikistr = html2txt(%param);
  $file =~ s/\.html$/\.txt/;
  if ($file !~ m/\.txt$/) { $file .= '.txt'; }
  writeFile($file, $wikistr);

  # upload txt
  print "done, creating DokuWiki page\n";
  $file = wikifyName($file);
  $param{'filename'} = decode($param{'inencoding'}, $file);
  # trim page name if it is longer than 255 symbols
  $param{'filename'} = trimName($param{'filename'});
  $param{'wikistr'} = decode($param{'outencoding'}, $wikistr);
  $file = uploadPage(%param);
  $file = encode('windows-1251', $file);
  
  $version{$originalfile} = $modified;
  
  print encode('windows-866', decode('windows-1251', "page $file created\n"));
}

$json = encode_json(\%version);
writeFile($param{'version'}, $json);

print "HUGE SUCCESS\n";

#==========================#

sub getFileNames {
  my (%param) = @_;

  my @files;
  if (@ARGV) {
    for my $filename (@ARGV) {
      push( @files, $filename );
    }
  }
  else {
    find(sub {
      if ( /(\.rtf$)|(\.doc$)/ ) {
        my $filename = $File::Find::name;
        push( @files, $filename );
      }
    }, $CURRENTDIR);
  }

  return @files;
}

sub wikiConnect {
  my (%param) = @_;

  my $client = RPC::XML::Client->new(
    $param{'endpoint'},
    useragent => [ cookie_jar => { file => $param{'cookies'}} ]);

  my $req = RPC::XML::request->new(
    'dokuwiki.login',
    RPC::XML::string->new( $param{'login'} ),
    RPC::XML::string->new( $param{'password'} ));
  my $res = $client->send_request($req);
  
  if (!$res->value()) { die "Could not connect to DokuWiki\n"; }
  
  return $client;
}

sub getLastModifiedDate {
  my $file = pop @_;
  
  open my $fh, '<', $file;
  my $timestamp = ctime(stat($fh)->mtime) or localtime;
  close $fh;

  return $timestamp;
}

sub rtf2html {
  my (%param) = @_;

  $param{'filename'} =~ s/\//\\/g;
  my $result = `"$param{'python'}" unoconv -i FilterOptions=$param{'inencoding'} -e FilterOptions=$param{'outencoding'} -f html "$param{'filename'}" 2>&1`;
  if ($result) { print "$result\nCould not convert to html\n"; return 0; }
  $param{'filename'} =~ s/(\.rtf$)|(\.doc$)/\.html/;
  # *~%magic%~*
  my $output = readFile($param{'filename'});
  $output = encode( $param{'outencoding'}, decode($param{'inencoding'}, $output) );
  writeFile($param{'filename'}, $output);

  return $param{'filename'};
}

sub html2txt {
  my (%param) = @_;
  
  my $htmltowiki = new HTML::WikiConverter(dialect => $param{'dialect'});
  my $wikistr = $htmltowiki->html2wiki(
    html => $param{'htmlstr'},
    wrap_in_html => 0,
    wiki_uri => 
      [qr~($param{'wikiuri'})~],
    escape_entities => 0
  );
  
  return $wikistr;
}

sub readFile {
  my $fname = pop @_;
  
  local $/ = undef;
  open my $fhandle, $fname or die "Could not open file: $!";
  my $fstr = <$fhandle>;
  close $fhandle;
  
  return $fstr;
}

sub writeFile {
  my ($fname, $fstr) = @_;
  
  open my $fhandle, '>', $fname or die "Could not open file: $!";
  print $fhandle $fstr
     or die "Could not write file: $!";
  close $fhandle;
  
  return 1;
}

sub wikifyName {
  my $file = pop @_;

  $file =~ s/\\/\//g;
  $file =~ s/^($CURRENTDIR)//;
  $file =~ s/(\.rtf$)|(\.html$)|(\.txt$)//;
  $file =~ s/\//:/g;
  $file = 'veda'.$file;

  return $file;
}

sub uploadPage {
  my (%param) = @_;
  
  my $req = RPC::XML::request->new(
    'wiki.putPage',
    RPC::XML::string->new($param{'filename'}),
    RPC::XML::string->new($param{'wikistr'}),
    RPC::XML::struct->new());
  my $res = $client->send_request($req);

  eval {$res->value()};

  if ($@) {
    die "$@\nCould not upload txt to DokuWiki";
  }
  
  return $param{'filename'};
}

sub measureName {
  my ($str) = @_;
  my $count = 0;
  
  for my $char (split //, $str) {
    if ($char =~ /\p{Cyrillic}/) {
	  $count += $CYRILLIC_WIDTH;
	}
	else {
	  $count += $NON_CYRILLIC_WIDTH;
	}
  }
  
  return $count;
}

sub trimName {
  my ($str) = @_;
  
  my $pagename = $str;
  # if namespaces are present, grab only page name
  $pagename = $1 if ($str =~ m/([^:]+)$/);
  
  while ( measureName($pagename)>$MAX_NAME_LENGTH ) {
    chop $pagename;
  }
  
  $str =~ s/[^:]+$/$pagename/;
  
  return $str;
}
