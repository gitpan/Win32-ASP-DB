package Win32::ASP::DBRecordGroup;
use Error qw/:try/;
use Win32::ASP::Error;

use strict vars;

sub _MIN_COUNT {
}

sub _NEW_COUNT {
}

sub new {
  my $class = shift;

  my $self = {
  };
  bless $self, $class;
  return $self;
}

sub query {
  my $self = shift;
  my($ref2constraints, $order, $columns) = @_;

  exists ($self->{orig}) and return;

  my $ref2columns;
  if (!defined $columns or $columns !~ /\S/ or $columns =~ /\*/) {
    $columns = '*';
  } else {
    my %columns;
    %columns = map {$_, 1} grep {/\S/} split(/,/, $columns);
    $columns = join(', ', sort keys %columns);
    $ref2columns = \%columns;
  }

  my(@constraints);
  foreach my $field (keys %{$ref2constraints}) {
    my $value = $ref2constraints->{$field};
    $value eq '' and next;
    if (exists($self->_QUERY_METAS->{$field})) {
      push(@constraints, &{$self->_QUERY_METAS->{$field}}($value));
    } else {
      push(@constraints, "$field = ".$self->_TYPE->_FIELDS->{$field}->as_sql($value));
    }
  }
  my $constraints = join(" AND\n    ", grep(/\S/, @constraints));
  $constraints and $constraints = 'WHERE '.$constraints;

  my(@order) = split(/,/, $order);
  foreach my $i (@order) {
    $i =~ /^(-?)(.+)$/ or
        throw Win32::ASP::Error::DBRecordGroup::bad_order (order => $i);
    my($asc, $field) = ($1, $2);
    exists $self->_TYPE->_FIELDS->{$field} or
        throw Win32::ASP::Error::Field::non_existent (fieldname => $field, method => 'Win32::ASP::DBRecordGroup::query');
    $asc eq '-' and $asc = ' DESC';
    $i = $field.$asc;
  }
  $order = join(" ,\n    ", @order);
  $order and $order = 'ORDER BY '.$order;

  my $SQL = "SELECT $columns FROM ".$self->_TYPE->_READ_SRC."\n$constraints\n$order";
  my $results = $self->_DB->exec_sql($SQL);

  until ($results->EOF) {
    my $record = $self->_TYPE->new;
    try {
      $record->_read($results, $ref2columns);
      $record->{parent} = $self;
      push(@{$self->{orig}}, $record);
    } otherwise {};
    $results->MoveNext;
  }
}


sub query_deep {
  my $self = shift;
  my($ref2constraints, $order, $columns) = @_;

  $self->query($ref2constraints, $order, $columns);

  scalar(@{$self->{orig}}) or return;

  my(@PRIMARY_KEY) = $self->_TYPE->_PRIMARY_KEY;
  my(@PRIMARY_SHT) = @PRIMARY_KEY;
  my $PRIMARY_LST = pop(@PRIMARY_SHT);

  my $index_hash = {};
  foreach my $i (0..$#{$self->{orig}}) {
    my $temp = $index_hash;
    foreach my $field (@PRIMARY_SHT) {
      $temp = $index_hash->{$self->{orig}->[$i]->{orig}->{$field}};
    }
    $temp->{$self->{orig}->[$i]->{orig}->{$PRIMARY_LST}} = $i;
  }

  foreach my $child (keys %{$self->_TYPE->_CHILDREN}) {
    my($type, $pkext) = @{$self->_TYPE->_CHILDREN->{$child}}{'type', 'pkext'};

    foreach my $i (0..$#{$self->{orig}}) {
      $self->{orig}->[$i]->{$child} = $type->new;
      $self->{orig}->[$i]->{$child}->{parent} = $self->{orig}->[$i];
    }

    my $temp = $type->new;
    $temp->query($ref2constraints, $pkext);

    my $record;
    while ($record = shift @{$temp->{orig}}) {
      my $temp = $index_hash;
      foreach my $field (@PRIMARY_SHT) {
        $temp = $index_hash->{$record->{orig}->{$field}};
      }
      exists $temp->{$record->{orig}->{$PRIMARY_LST}} or next;
      my $index = $temp->{$record->{orig}->{$PRIMARY_LST}};

      $record->{parent} = $self->{orig}->[$index]->{$child};
      push(@{$self->{orig}->[$index]->{$child}->{orig}}, $record);
    }
  }
}

sub index_hash {
  my $self = shift;

  my $retval = {};
  foreach my $i (0..$#{$self->{orig}}) {
    $retval->{$self->{orig}->[$i]->{orig}->{ChangeID}} = $i;
  }

  return $retval;
}



sub insert {
  my $self = shift;

  foreach my $i (0..$#{$self->{edit}}) {
    try {
      $self->{edit}->[$i]->insert;
    } otherwise {
      my $E = shift;
      throw Win32::ASP::Error::Field::group_wrapper (E => $E, row_type => $self->_TYPE->_FRIENDLY, row_id => $i+1, activity => 'insert');
    };
  }
}

sub delete {
  my $self = shift;

  foreach my $i (@{$self->{edit}}) {
    $i->delete;
  }
}

sub should_update {
  my $self = shift;

  if ($self->merge_inner) {
    my $retval = 1;
    foreach my $i (@{$self->{orig}}) {
      $i->should_update or $retval = 0;
    }
    $self->split_inner;
    return $retval;
  } else {
    return 0;
  }
}

sub update {
  my $self = shift;

  if ($self->should_update) {
    $self->merge_inner;
    foreach my $i (0..$#{$self->{orig}}) {
      try {
        $self->{orig}->[$i]->update;
      } otherwise {
        my $E = shift;
        throw Win32::ASP::Error::Field::group_wrapper (E => $E, row_type => $self->_TYPE->_FRIENDLY, row_id => $i+1, activity => 'update');
      };
    }
    $self->split_inner;
    return 0;
  } else {
    foreach my $i (@{$self->{orig}}) {
      $i->delete;
    }

    foreach my $i (0..$#{$self->{edit}}) {
      try {
        $self->{edit}->[$i]->insert;
      } otherwise {
        my $E = shift;
        throw Win32::ASP::Error::Field::group_wrapper (E => $E, row_type => $self->_TYPE->_FRIENDLY, row_id => $i+1, activity => 'update');
      };
    }
    return 1;
  }
}

sub edit {
  my $self = shift;

  unless (exists $self->{edit}) {
    foreach my $i (@{$self->{orig}}) {
      $i->edit;
    }
    $self->split_inner;
  }
}

sub merge_inner {
  my $self = shift;

  if ($#{$self->{orig}} == $#{$self->{edit}}) {
    foreach my $i (0..$#{$self->{orig}}) {
      $self->{orig}->[$i]->merge($self->{edit}->[$i]);
    }
    delete $self->{edit};
    return 1;
  } else {
    return 0;
  }
}

sub split_inner {
  my $self = shift;

  $self->{edit} = [];
  foreach my $i (@{$self->{orig}}) {
    push(@{$self->{edit}}, $i->split);
  }
}

sub post {
  my $self = shift;
  my($column) = @_;

  exists $self->_TYPE->_FIELDS->{$column} or
      throw Win32::ASP::Error::Field::non_existent (fieldname => $column, method => 'Win32::ASP::DBRecordGroup::post');
  my $count = $main::Request->Form($self->_TYPE->_FIELDS->{$column}->formname)->Count;

  my $orow = 0;
  foreach my $irow (1..$count) {
    my $record = $self->_TYPE->new;
    $record->post($irow);
    if ($record->row_check($orow)) {
      $record->{parent} = $self;
      push(@{$self->{edit}}, $record);
      $orow++;
    }
  }
}

sub add_extras {
  my $self = shift;

  my $new;
  my $min_count = $self->_MIN_COUNT;
  my $new_count = $self->_NEW_COUNT;
  defined $min_count && defined $new_count or return;

  my $cur_count = scalar(@{$self->{edit}});
  $cur_count < $min_count and $new = $min_count - $cur_count;
  $new < $new_count and $new = $new_count;

  foreach my $i (1..$new) {
    my $record = $self->_TYPE->new;
    $record->{parent} = $self;
    $record->init;
    push(@{$self->{edit}}, $record);
  }
}

sub set_prop {
  my $self = shift;
  my($fieldname, $value) = @_;

  foreach my $i (@{$self->{edit}}) {
    $i->{edit}->{$fieldname} = $value;
  }
}

sub gen_table {
  my $self = shift;
  my($columns, $data, $viewtype, %params) = @_;

  $viewtype eq 'edit' and $self->add_extras;

  my(@columns) = split(/,/, $columns);

  foreach my $field (@columns) {
    exists $self->_TYPE->_FIELDS->{$field} or
        throw Win32::ASP::Error::Field::non_existent (fieldname => $field, method => 'Win32::ASP::DBRecordGroup::gen_table');
  }

  my $retval = <<ENDHTML;
<TABLE border="1" cellpadding="3" bordercolordark="#000000" bordercolorlight="#000000">
  <TR>
ENDHTML

  foreach my $field (@columns) {
    $retval .= "    <TH>".$self->_TYPE->_FIELDS->{$field}->desc."</TH>\n";
  }
  $retval .= "  </TR>\n";

  foreach my $record (@{$self->{$data}}) {
    $retval .= "  <TR>\n";
    foreach my $field (@columns) {
      $retval .= "    <TD valign=\"top\">";
      my $temp;
      $temp = $record->field($field, $data, $viewtype);
      if ($viewtype eq 'view' and $params{active} eq $field) {
        $temp = "<A HREF=\"$params{activedest}=$record->{$data}->{$field}\">$temp</A>";
      }
      $retval .= $temp."</TD>\n";
    }
    $retval .= "  </TR>\n";
  }
  $retval .= "</TABLE>\n";

  return $retval;
}

sub get_QS_constraints {
  my(%constraints);

  my $count = $main::Request->QueryString('constraint')->{Count};
  foreach my $i (1..$count) {
    my $constraint = $main::Request->QueryString('constraint')->Item($i);
    $constraint =~ /^([^=]+)=([^=]*)$/ or
        throw Win32::ASP::Error::DBRecordGroup::bad_constraint (constraint => $constraint);
    $constraints{$1} = $2;
  }
  return %constraints;
}

sub make_QS_constraints {
  my(%constraints) = @_;

  return map {return (constraint => "$_=$constraints{$_}")} keys %constraints;
}

sub debug_dump {
  my $self = shift;

  $main::Response->Write("<XMP>".Data::Dumper->Dump([$self], ['self'])."</XMP>");
}



####################### Error Classes ##################################333

package Win32::ASP::Error::DBRecordGroup;
@Win32::ASP::Error::DBRecordGroup::ISA = qw/Win32::ASP::Error/;


package Win32::ASP::Error::DBRecordGroup::bad_constraint;
@Win32::ASP::Error::DBRecordGroup::bad_constraint::ISA = qw/Win32::ASP::Error::DBRecordGroup/;

#Parameters:  constraint

sub _as_html {
  my $self = shift;

  my $constraint = $self->constraint;
  return <<ENDHTML;
Improperly formed constraint "$constraint".<P>
ENDHTML
}



package Win32::ASP::Error::DBRecordGroup::bad_order;
@Win32::ASP::Error::DBRecordGroup::bad_order::ISA = qw/Win32::ASP::Error::DBRecordGroup/;

#Parameters:  order

sub _as_html {
  my $self = shift;

  my $order = $self->order;
  return <<ENDHTML;
Improperly formed order element "$order".<P>
ENDHTML
}


1;
