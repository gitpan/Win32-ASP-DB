use Win32::ASP::Field;
use Error qw/:try/;
use Win32::ASP::Error;

package Win32::ASP::Field::bit;

@ISA = ('Win32::ASP::Field');

use strict;

sub _check_value {
  my $self = shift;
  my($value) = @_;

  if ($value ne '0' and $value ne '1') {
    throw Win32::ASP::Error::Field::bad_value (field => $self, bad_value => $value,
        error => "The value is not a bit value.");
  }

  $self->SUPER::_check_value($value);
}

sub _as_html_view {
  my $self = shift;
  my($record, $data) = @_;

  my $value = $record->{$data}->{$self->name};
  return $value ? 'Yes' : 'No';
}

sub _as_html_edit_rw {
  my $self = shift;
  my($record, $data) = @_;

  my $formname = $self->formname;
  my $value = $record->{$data}->{$self->name};
  my $help = $self->as_html_mouseover($record, $data);

  my $yes = $value ? 'CHECKED' : '';
  my $no =  $value ? '' : 'CHECKED';
  chomp(my $retval = <<ENDHTML);
<INPUT $yes NAME="$formname" TYPE="radio" VALUE="1" $help>Yes
<INPUT $no  NAME="$formname" TYPE="radio" VALUE="0" $help>No
ENDHTML
  return $retval;
}

sub _as_sql {
  my $self = shift;
  my($value) = @_;

  $self->check_value($value);
  return $value;
}

1;
