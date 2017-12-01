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
  { :offset(0), :len(100), :name<name>, :gen(sub (IO $f, Int $len = 100) {
      my $r = $f.relative.chars > $len
        ?? Buf.new((pax-pack('path', $f.relative)//('PaxHeader/'~$f.basename.substr(0,88))).encode('utf8').values)
        !! Buf.new($f.basename.encode('utf8').values);
      $r.append(gen-empty($r.elems+1..$len));
      $r;
    })
  },
  { :offset(100), :len(8), :name<mode>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new(($f.mode.Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    })
  },
  { :offset(108), :len(8), :name<uid>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new((nqp::stat($f.absolute, 10).base(8)~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    }),
  },
  { :offset(116), :len(8), :name<gid>, :gen(sub (IO $f, Int $len = 8) {
      my $mask = Buf.new((nqp::stat($f.absolute, 11).base(8)~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len-1, '0'.ord), |$mask, |Buf.new(0));
    }),
  },
  { :offset(124), :len(12), :name<size>, :gen(sub (IO $f, Int $len = 12) {
      my $mask = Buf.new(($f.s.base(8).Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :offset(136), :len(12), :name<modified>, :gen(sub (IO $f, Int $len = 12) {
      my $mask = Buf.new(($f.modified.DateTime.posix.base(8).Str~' ').encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :offset(148), :len(8), :name<checksum>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(gen-empty(1..$len, ' '.ord));
    }),
  },
  { :offset(156), :len(1), :name<type-flag>, :gen(sub (IO $f, Int $len = 1) {
      my $mask = Buf.new((nqp::stat($f.absolute, 12) ?? 1 !! $f~~:d ?? 5 !! 0).Str.encode('utf8').values);
      if %*EXT.keys {
        %*EXT<type-flag> = Buf.new(gen-empty(2..$len, '0'.ord), 'x'.encode('utf8').values);
      }
      Buf.new(gen-empty($mask.elems+1..$len, '0'.ord), |$mask);
    }),
  },
  { :offset(157), :len(100), :name<link-name>, :gen(sub (IO $f, Int $len = 100) {
      my $mask = Buf.new((nqp::stat($f.absolute, 12) ?? nqp::readlink($f.absolute) !! '').Str.encode('utf8').values);
      Buf.new(gen-empty($mask.elems+1..$len, 0), |$mask);
    }),
  },
  { :offset(257), :len(8), :name<ustar>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new('ustar'.encode('utf8').values, 0x00, gen-empty(0..1, '0'.ord));
    }),
  },
  { :offset(265), :len(32), :name<uname>, :gen(sub (IO $f, Int $len = 32) {
      my $uname = 'unknown';
      Buf.new($uname.encode('utf8').values, gen-empty($uname.chars..^32));
    }),
  },
  { :offset(297), :len(32), :name<gname>, :gen(sub (IO $f, Int $len = 32) {
      my $gname = 'unknown';
      Buf.new($gname.encode('utf8').values, gen-empty($gname.chars..^32));
    }),
  },
  { :offset(329), :len(8), :name<major>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(('0' x 6 ~ ' ').encode('utf8').values, 0);
    }),
  },
  { :offset(337), :len(8), :name<minor>, :gen(sub (IO $f, Int $len = 8) {
      Buf.new(('0' x 6 ~ ' ').encode('utf8').values, 0);
    }),
  },
  { :offset(345), :len(155), :name<prefix>, :gen(sub (IO $f, Int $len = 155) {
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

sub no (Buf $x) {
  "\|{$x.decode('utf8').subst(/"\0"|"\n"|"\r"/, '.', :g).subst(/(. ** 16)/, { $0 ~ "|\n|" }, :g)}\|";
}

sub read-tar(IO $file) is export { #expects a tar file
  my $buffer = $file.slurp :bin;
  my $cursor = 0;
  my Buf $f;
  my ($fname, $fsize, $ftype);
  my $files = 0;
  my @fs;
  my %idx =
    t => @headers.grep(*<name> eq 'type-flag')[0],
    n => @headers.grep(*<name> eq 'name')[0],
    s => @headers.grep(*<name> eq 'size')[0],
  ;
  while $cursor < $buffer.elems {
    #get header - 
    $f.=new;
    $f.push($buffer.subbuf($cursor, $record-size));
    $ftype   = $f.subbuf(%idx<t><offset>, %idx<t><len>).decode('utf8').subst(/"\0"/,'',:g);
    $fname   = $f.subbuf(%idx<n><offset>, %idx<n><len>).decode('utf8').subst(/"\0"/,'',:g);
    $fsize   = :8($f.subbuf(%idx<s><offset>, %idx<s><len>).decode('utf8').subst(/"\0"/,'',:g))//0;
    $cursor += $record-size;
    if $ftype eq ('x') {
      $f.push($buffer.subbuf($cursor, $record-size));
      # parse this;
      next;
    }
    #read fdata
    $f.push($buffer.subbuf($cursor, $fsize))
      if $ftype eq ('0'|'1'|'g');
    $cursor += $fsize + $record-size - ($fsize % $record-size)
      if $ftype eq ('0'|'1'|'g');
    @fs.push({
      name    => $fname,
      written => 1,
      io      => Nil,
    });
    say "$ftype:$fname ($fsize)\n========>\n{no $f.subbuf(*-$fsize)}\<===========\n\n";
    #die 'ded' if $files++ == 2;
  }
}
