use Error::Unhandled;
use Class::SelfMethods;

use strict;

package Win32::ASP::Error;
@Win32::ASP::Error::ISA = qw/Error::Unhandled Class::SelfMethods/;

sub unhandled {
  my $self = shift;

  $main::Response->Clear;
  my $title = $self->title;
  my $mesg = $self->as_html;
  $main::Response->Write(<<ENDHTML);
<html>

<head>
<title>Error: $title</title>

</head>

<body bgcolor="#FFFFE1" text="#000000" link="#0000FF" vlink="#800080" alink="#4000C0">
$mesg
</body>
</html>
ENDHTML

  $main::Response->Flush;
  $main::Response->End;
  die;
}

sub title {
  my $self = shift;

  return "";
}

1;

