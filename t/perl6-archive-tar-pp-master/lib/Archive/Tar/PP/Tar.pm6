use Archive::Tar::PP::Util;# qw<$record-size>;
 
class Archive::Tar::PP::Tar {
  has Int  $!size = $record-size * 2;
  has @!buffer;
  has IO $!file-name;

  submethod BUILD (IO :$!file-name) {
    die 'Provide a file name for tar.'
      unless $!file-name;
  }

  method header-size {
    $record-size;
  }
  method data-size($file where * ~~ (IO|Str)){
    $file ~~ IO ?? $file.s !! $file.IO.s;
  }

  method push(*@files){
    $!size = [+] @files.grep(* ~~ any(IO|Str) ).map({
      my $x = $_ ~~ IO ?? $_ !! $_.IO;
      warn 'Could not find file to tar: '~$x.relative, next
        unless $x ~~ :e;
      @!buffer.push((
        name    => $x.relative,
        written => 0,
        io      => $x,
      ).Hash);
      $.data-size($x) + $.header-size;
    });
  }

  method extend-file {
    # TODO
  }

  method write {
    my Buf $buffer .=new;
    for @!buffer.grep(!*.<written>) -> $entry {
      $buffer.push: form-header($entry<io>);
      $buffer.push: form-data($entry<io>);
    }
    for 0 ..^2 {
      $buffer.push(form-header);
    }
    $!file-name.spurt($buffer, :b);
  }

}
