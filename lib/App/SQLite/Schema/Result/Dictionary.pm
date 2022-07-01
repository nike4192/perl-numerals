use utf8;
package App::SQLite::Schema::Result::Dictionary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

App::SQLite::Schema::Result::Dictionary

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<dictionary>

=cut

__PACKAGE__->table("dictionary");

=head1 ACCESSORS

=head2 id

  data_type: 'int'
  is_nullable: 0

=head2 word

  data_type: 'varchar'
  is_nullable: 0
  size: 35

=head2 morph

  data_type: 'longtext'
  is_nullable: 0

=head2 frequency

  data_type: 'float'
  is_nullable: 0

=head2 proper_name

  data_type: 'tinyint'
  is_nullable: 0
  size: 1

=head2 pronunciation

  data_type: 'varchar'
  is_nullable: 0
  size: 35

=head2 description

  data_type: 'text'
  is_nullable: 0

=head2 base_id

  data_type: 'int'
  is_nullable: 0

=head2 path

  data_type: 'varchar'
  is_nullable: 0
  size: 50

=head2 value

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "int", is_nullable => 0 },
  "word",
  { data_type => "varchar", is_nullable => 0, size => 35 },
  "morph",
  { data_type => "longtext", is_nullable => 0, accessor => '_morph' },  # Added accessor
  "frequency",
  { data_type => "float", is_nullable => 0 },
  "proper_name",
  { data_type => "tinyint", is_nullable => 0, size => 1 },
  "pronunciation",
  { data_type => "varchar", is_nullable => 0, size => 35 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "base_id",
  { data_type => "int", is_nullable => 0 },
  "path",
  { data_type => "varchar", is_nullable => 0, size => 50 },
  "value",
  { data_type => "text", is_nullable => 1, accessor => '_value' },  # Added accessor
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-06-28 22:20:30
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zUQrmUDsNGudC8NNqfCRjg

__PACKAGE__->belongs_to(
    base_word =>
    'App::SQLite::Schema::Result::Dictionary',
    'base_id'
);

use JSON;

sub morph {
    my ($self, $value) = @_;
    return decode_json($self->_morph());
}

sub value {
    my ($self) = @_;
    if ($self->base_word) {
        return $self->base_word->value;   # Recursion
    } else {
        return $self->_value;
    }
}

sub main_word {
    my ($self) = @_;
    if ($self->base_word) {
        return $self->base_word->main_word;   # Recursion
    } else {
        return $self;
    }
}

sub TO_JSON {
    my $self = shift;
    return {
        "id"            => $self->id,
        "word"          => $self->word,
        "morph"         => $self->morph,
        "frequency"     => $self->frequency,
        "proper_name"   => $self->proper_name,
        "pronunciation" => $self->pronunciation,
        "description"   => $self->description,
        "base_id"       => $self->base_id,
        "path"          => $self->path,
        "value"         => $self->value
    }
}
# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
