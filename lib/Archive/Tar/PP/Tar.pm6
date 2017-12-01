use Archive::Tar::PP::Util;
 
class Archive::Tar::PP::Tar {
  has @!buffer;
  has IO $!file-name;
  has $!state;

  submethod BUILD (IO :$!file-name, :@!buffer) {
    die 'Provide a file name for tar.'
      unless $!file-name;
    $!state = @!buffer.elems ?? 'tar' !! 'extracted';
  }

  method push(*@files){
    @files.grep(* ~~ any(IO|Str) ).map({
      my $x = $_ ~~ IO ?? $_ !! $_.IO;
      warn 'Could not find file to tar: '~$x.relative, next
        unless $x ~~ :e;
      @!buffer.push((
        name    => $x.relative,
        written => 0,
        io      => $x,
      ).Hash);
    });
  }

  method ls {
    @!buffer.map({ $_<name> });
  }

  method write($fn?, Bool :$force = False) {
    my $f = !$fn.defined ?? $!file-name !! $fn ~~ IO ?? $fn !! $fn.IO;
    die "File exists {$f.relative}, please use :force to overwrite"
      if (!$force && $f ~~ :e && $f ne $!file-name.relative);
    my Buf $buffer .=new;
    for @!buffer.grep(!*.<written>) -> $entry {
      $buffer.push: form-header($entry<io>);
      $buffer.push: form-data($entry<io>);
    }
    for 0 ..^2 {
      $buffer.push(form-header);
    }
    $!file-name.spurt($buffer, :b);
    $!state = 'tar';
  }

  method state { $!state; }

}
