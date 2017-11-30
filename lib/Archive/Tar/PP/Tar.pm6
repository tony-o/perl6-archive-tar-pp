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

  method allocate-buffer(*@files){
    $!size = [+] @files.grep(* ~~ IO).map({
      @!buffer.push((
        name    => $_.relative,
        buffer  => @[$.data-size($_) + $.header-size],
        written => 0,
        io      => $_,
      ).Hash);
      $.data-size($_) + $.header-size;
    });
  }

  method extend-file {
    # TODO
  }

  method write {
    my Buf $buffer .=new;
    @!buffer.perl.say;
    for @!buffer.grep(!*.<written>) -> $entry {
      $buffer.push: form-header($entry<io>);
      $buffer.push: form-data($entry<io>);
    }
    for 0 .. 2 {
      'empy'.say;
      $buffer.push(form-header);
    }
    $!file-name.spurt($buffer, :b);
    dump-buf($buffer);
  }

}
