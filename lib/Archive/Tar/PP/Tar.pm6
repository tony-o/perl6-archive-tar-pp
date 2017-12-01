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
        type    => $x ~~ :d ?? 'd' !! 'f',
      ).Hash);
    });
  }

  method ls {
    @!buffer.map({ $_<name> });
  }

  method peek(Str $fn) {
    my $f = @!buffer.grep(*<name> eq $fn);
    return Nil
      unless $f || $f.elems == 0;
    $f=$f[0];
    #die $f<data>.subbuf(0, $f<fsize>).perl if $fn ~~ /'x.pl6'/;
    my Buf $b.=new;
    $f<data>.perl.say;
    try { $b = $f<data>.subbuf(0, $f<fsize>); CATCH { default { .say } }};
    ($f<type>//'') => $b;
  }

  method write($fn?, Bool :$force = False) {
    my $f = !$fn.defined ?? $!file-name !! $fn ~~ IO ?? $fn !! $fn.IO;
    die "File exists {$f.relative}, please use :force to overwrite"
      if (!$force && $f ~~ :e && $f ne $!file-name.relative);
    my Buf $buffer .=new;
    my $cursor = 0;
    for @!buffer -> $entry is rw {
      my $header = form-header($entry<io>);
      my $data   = form-data($entry<io>);
      $buffer.push: $header;
      $buffer.push: $data;
      $entry<fsize>  = :8(($header.elems == 1024
        ?? $header.subbuf(512+124, 12)
        !! $header.subbuf(124, 12)
      ).decode('utf8').subst(/"\0"/, '', :g))//0;
      $entry<header> = $header;
      $entry<data>   = $data;
    }
    for 0 ..^2 {
      $buffer.push(form-header);
    }
    $!file-name.spurt($buffer, :b);
    $!state = 'tar';
  }

  method state { $!state; }

}
