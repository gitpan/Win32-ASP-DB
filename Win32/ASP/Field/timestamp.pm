use Win32::ASP::Field;
use Error qw/:try/;
use Win32::ASP::Error;

package Win32::ASP::Field::timestamp;

@ISA = ('Win32::ASP::Field');

use strict;

sub _read {
  my $self = shift;
  my($record, $results, $columns) = @_;

  my $name = $self->name;
  ref($columns) and !$columns->{$name} and return;
  $self->can_view($record) or return;
  if ($results->Fields->Item($name)) {
    my $temp = uc(unpack('H*', $results->Fields->Item($name)->Value));
    $temp =~ s/^0+//;
    $record->{orig}->{$name} = $temp;
  }
}

sub _as_html_view {
  my $self = shift;
  my($record, $data) = @_;

  return '';
}

sub _as_html_edit_ro {
  my $self = shift;
  my($record, $data) = @_;

  my $formname = $self->formname;
  my $value = $record->{$data}->{$self->name};

  chomp(my $retval = <<ENDHTML);
<INPUT TYPE="HIDDEN" NAME="$formname" VALUE="$value">
ENDHTML
  $retval .= $self->as_html_view;
  return $retval;
}

1;
