use Benchmark;

package Win32::ASP::Profile;

use strict;

BEGIN {
  $Win32::ASP::Profile::start = Benchmark->new;
  $Win32::ASP::Profile::start_tick = Win32::GetTickCount();
}

sub END {
  my $end = Benchmark->new;
  my $end_tick = Win32::GetTickCount();

  my $delta = Benchmark::timediff($end, $Win32::ASP::Profile::start);
  my $deltastr = Benchmark::timestr($delta);
  $deltastr =~ s/\s+\d+//;
  $deltastr = sprintf("%0.2f", ($end_tick - $Win32::ASP::Profile::start_tick)/1000).$deltastr;

  $main::Response->Write("<HR>$deltastr");
}

1;
