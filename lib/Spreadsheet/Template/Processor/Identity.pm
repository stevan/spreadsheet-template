package Spreadsheet::Template::Processor::Identity;
use Moose;

does 'Spreadsheet::Template::Processor';

sub process {
    my $self = shift;
    my ($contents, $vars) = @_
    return $contents;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
