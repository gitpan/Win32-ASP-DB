use Win32::ASP::Field::bit;
use Error qw/:try/;
use Win32::ASP::Error;

package Win32::ASP::Field::boolean;

@ISA = ('Win32::ASP::Field::bit');

use strict;

sub _as_sql {
  my $self = shift;
  my($value) = @_;

  $self->check_value($value);
  return -$value;
}

1;
