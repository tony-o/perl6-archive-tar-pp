unit module Archive::Tar::PP::Util;
use nqp;

our $record-size is export = 512;

sub gen-empty(Range $range, $val = 0x00) {
  #return Buf.new if $range.min >= $range.max;
  |$range.map({ $val });
}

sub pax-pack($name, $value) {
  %*EXT{$name} = sprintf("%d %s=%s\n", "$name=$value\n".chars+4, $name, $value);
  Nil;
}

my @headers =
  { :type<string>, :len(100), :name<name>, :gen(sub (IO $f, Int $len = 100) {
      my $r = $f.relative.chars > $len
        ?? Buf.new((pax-pack('path', $f.relative)//('PaxHeader/'~$f.basename.substr(0,88))).encode('utf8').values)
        !! Buf.new($f.basename.encode('utf8').values);
      $r.append(gen-empty($r.elems+1..$len));
      $r;
    })
  },
  { :type<string>, :len(8), :name<mode>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new(($f.mode.Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    })
  },
  { :type<octal>, :len(8), :name<uid>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new((nqp::stat($f.absolute, 10).base(8)~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    }),
  },
  { :type<octal>, :len(8), :name<gid>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new((nqp::stat($f.absolute, 11).base(8)~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    }),
  },
  { :type<octal>, :len(12), :name<size>, :gen(sub (IO $f, Int $len = 12) {
      my $mask = Buf.new(($f.s.base(8).Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :type<octal>, :len(12), :name<modified>, :gen(sub (IO $f, Int $len = 12) {
      my $mask = Buf.new(($f.modified.DateTime.posix.base(8).Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :type<octal>, :len(8), :name<checksum>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(gen-empty(1..$len, ' '.ord));
    }),
  },
  { :type<string>, :len(2), :name<type-flag>, :gen(sub (IO $f, Int $len = 1) {
      my $mask = Buf.new((nqp::stat($f.absolute, 12) ?? 1 !! $f~~:d ?? 5 !! 0).Str.encode('utf8').values);
      if %*EXT.keys {
        %*EXT<type-flag> = Buf.new(gen-empty(2..$len, '0'.ord), 'x'.encode('utf8').values);
      }
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :type<string>, :len(100), :name<link-name>, :gen(sub (IO $f, Int $len = 100) {
      my $mask = Buf.new((nqp::stat($f.absolute, 12) ?? nqp::readlink($f.absolute) !! '').Str.encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, 0), |$mask);
    }),
  },
  { :type<string>, :len(8), :name<ustar>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new('ustar'.encode('utf8').values, 0x00, gen-empty(0..1, '0'.ord));
    }),
  },
  { :type<string>, :len(32), :name<uname>, :gen(sub (IO $f, Int $len = 32) {
      my $uname = 'unknown';
      Buf.new($uname.encode('utf8').values, gen-empty($uname.chars..^32));
    }),
  },
  { :type<string>, :len(32), :name<gname>, :gen(sub (IO $f, Int $len = 32) {
      my $gname = 'unknown';
      Buf.new($gname.encode('utf8').values, gen-empty($gname.chars..^32));
    }),
  },
  { :type<int>, :len(8), :name<major>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(('0' x 6 ~ ' ').encode('utf8').values, 0);
    }),
  },
  { :type<int>, :len(8), :name<minor>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(('0' x 6 ~ ' ').encode('utf8').values, 0);
    }),
  },
  { :type<string>, :len(155), :name<prefix>, :gen(sub (IO $f, Int $len = 155) {
      my $mask = Buf.new(($f.dirname ne '.' && %*EXT.keys.elems == 0 ?? $f.dirname !! '').Str.encode('utf8').values);
      Buf.new(|$mask, gen-empty($mask.elems..^$len));
    }),
  },
;

sub form-header(IO $file?) is export {
  return Buf.new(gen-empty(1..$record-size))
    unless $file.defined;
  my Buf $header .=new;
  my Buf $ext    .=new;
  my $lst = 0;
  my %*EXT; 
  for @headers -> $h {
    my $b-d = $h<gen>($file);
    $ext.push(%*EXT{$h<name>}.defined ?? %*EXT{$h<name>} !! $b-d);
    $header.push($b-d);
    $lst = $header.elems;
  }
  #fix $ext size attribute
  if %*EXT.keys {
    $ext.push(Buf.new(gen-empty($ext.elems..^$record-size)));
    my $x = 0;
    for %*EXT.keys { 
      next if $_ eq 'type-flag';
      $x += %*EXT{$_}.substr(0, %*EXT{$_}.index(' ')).Int;
      $ext.push(Buf.new(%*EXT{$_}.encode('utf-8').values));
    }
    $x = Buf.new($x.base(8).Str.encode('utf-8').values);
    $x = Buf.new(gen-empty($x.elems+1..11, '0'.ord), |$x);
    for (0..10) {
      $ext[$_+124] = $x[$_];
    }
  }
  #check-sum time
  my $cs = 0;
  my $cs-ext = 0;
  for (0..^$header.elems) {
    $cs = ($cs + $header[$_]) % 262144;
    $cs-ext = ($cs-ext + $ext[$_]) % 262144 if %*EXT.keys.elems;
  }
  my Buf $cb = Buf.new(sprintf('%s%s', gen-empty(1..^7 - $cs.base(8).Str.chars, '0').join(''),$cs.base(8).Str).encode('utf8').values);
  my Buf $cb-ext = Buf.new(sprintf('%s%s', gen-empty(1..^7 - $cs-ext.base(8).Str.chars, '0').join(''),$cs-ext.base(8).Str).encode('utf8').values) if %*EXT.keys.elems;
  for (0..6) {
    $header[148+$_] = $cb[$_];
    $ext[148+$_] = $cb-ext[$_] if %*EXT.keys.elems;
  }
  $header.push(Buf.new(gen-empty($header.elems..^$record-size)));
  %*EXT<type-flag>:delete;
  #ret
  %*EXT.keys.elems ?? Buf.new(|$ext, |gen-empty(1..512-($ext.elems % $record-size)), |$header) !! $header;
}

sub form-data(IO $file) is export {
  my $empty = 1..$record-size - ($file.s % $record-size);
  $file ~~ :d ?? Buf.new() !! Buf.new(|$file.IO.slurp.encode('utf8'), gen-empty($empty));
}

sub dump-buf(Buf $b) is export {
  my $i = 0;
  my $append;
  while ($i < $b.elems) {
    printf '%010d  |%08x  ', $i, $i;
    for ($i..^$i+16) {
      FIRST { $append = ''; };
      printf '%02x ', $b[$_];
      print ' ' if so ($_+1) %% 8 && !so ($_+1) %% 16;
      $append ~= try { die unless $b[$_] ne any(0, 10, 13); $b[$_].chr } // '.';
      LAST { $i += 16; print "|$append|\n"};
    };
  }
  print "\n";
}

sub read-tar(IO $file) is export { #expects a tar file
  my %data;
  my $buffer = $file.slurp :bin;
  my $cursor = 0;
  my $CTRL = 0;
  my $f;
  my @buff;
  my $fname;
  my $psize = 0;
  while $cursor < $buffer.elems {
    $f = [] if $CTRL == 0;
    $CTRL++ #paxheader read
      if $CTRL == 1; 
    for @headers -> $h {
      $f.push(Buf.new($buffer.subbuf($cursor, $h<len> - 1)));    
      $CTRL = 1 # paxheader received
        if $h<name> eq 'type-flag' && $f[*-1].decode('utf-8') eq 'x';
      $psize = :8($f[*-1].decode('utf8')) // 0
        if $h<name> eq 'size';
      $fname = $f[*-1].decode('utf8').subst(/"\0"/, '', :g)
        if $h<name> eq 'name' && ($CTRL == 0 || !$fname.defined);
      $cursor += $h<len> - ($h<name> eq 'type-flag' ?? 1 !! 0);
    }
    $cursor += $record-size - ($cursor % $record-size);
    $f.push($buffer.subbuf($cursor, $psize));
    $cursor += $psize + ($record-size - ($psize % $record-size));
    if $CTRL == 1 {
      $fname = $f[*-1].decode('utf8');
      my ($x, $y) = '';
      while ($x ne 'path' && $fname.chars) { 
        $psize = :10($fname.substr(0, $fname.index(' ')));
        $x = $fname.substr($fname.index(' ')+1, 4);
        $fname = $fname.substr($fname.index(' ') + $psize)//''
          if $x ne 'path';
      }
      $fname = $fname.substr($psize.Str.chars + 6, $psize).trim
        if $x eq 'path';
    }
    if $CTRL == 2 || $CTRL == 0 {
      #TODO overwrite some headers
      @buff.push({
        name    => $fname,
        written => -1,
        buffer  => $f.clone,
      });
      $f = [];
      $fname = Any;
    }
  }
}
