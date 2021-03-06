package Spreadsheet::Template::Generator::Parser::Excel;
use Moose::Role;

use List::MoreUtils 'any';

with 'Spreadsheet::Template::Generator::Parser';

requires '_build_excel';

has excel => (
    is      => 'ro',
    isa     => 'Object',
    lazy    => 1,
    builder => '_build_excel',
);

sub parse {
    my $self = shift;
    return $self->_parse_workbook;
}

sub _parse_workbook {
    my $self = shift;

    my $data = {
        selection  => $self->excel->{SelectedSheet}, # XXX
        worksheets => [],
    };

    for my $sheet ($self->excel->worksheets) {
        push @{ $data->{worksheets} }, $self->_parse_worksheet($sheet);
    }

    return $data;
}

sub _parse_worksheet {
    my $self = shift;
    my ($sheet) = @_;

    my $data = {
        name          => $sheet->get_name,
        row_heights   => [ $sheet->get_row_heights ],
        column_widths => [ $sheet->get_col_widths ],
        selection     => $sheet->{Selection}, # XXX
        cells         => [],
    };

    my ($rmin, $rmax) = $sheet->row_range;
    my ($cmin, $cmax) = $sheet->col_range;

    splice @{ $data->{row_heights} }, $rmax + 1;
    splice @{ $data->{column_widths} }, $cmax + 1;

    for my $row (0..$rmin - 1) {
        push @{ $data->{cells} }, [];
    }

    for my $row ($rmin..$rmax) {
        my $row_data = [];
        for my $col (0..$cmin - 1) {
            push @$row_data, {};
        }
        for my $col ($cmin..$cmax) {
            if (my $cell = $sheet->get_cell($row, $col)) {
                push @$row_data, $self->_parse_cell($cell);
            }
            else {
                push @$row_data, {};
            }
        }
        push @{ $data->{cells} }, $row_data
    }

    return $data;
}

sub _parse_cell {
    my $self = shift;
    my ($cell) = @_;

    my $contents = $cell->unformatted;
    my $type = $cell->type;
    my $formula = $cell->{Formula}; # XXX
    my $format = $cell->get_format;

    if ($type eq 'Numeric') {
        $type = 'number';
    }
    elsif ($type eq 'Text') {
        $type = 'string';
    }
    elsif ($type eq 'Date') {
        $type = 'date_time';
    }
    else {
        die "unknown type $type";
    }

    my $format_data = {};
    if ($format) {
        my %halign = (
            0 => 'none',
            1 => 'left',
            2 => 'center',
            3 => 'right',
            4 => 'fill',
            5 => 'justify',
            6 => 'center_across',
            # XXX this isn't supported by Spreadsheet::WriteExcel
            7 => 'distributed',
        );

        my %valign = (
            0 => 'top',
            1 => 'vcenter',
            2 => 'bottom',
            3 => 'vjustify',
            # XXX this isn't supported by Spreadsheet::WriteExcel
            4 => 'vdistributed',
        );

        my %border = (
            0  => 'none',
            1  => 'thin',
            2  => 'medium',
            3  => 'dashed',
            4  => 'dotted',
            5  => 'thick',
            6  => 'double',
            7  => 'hair',
            8  => 'medium_dashed',
            9  => 'dash_dot',
            10 => 'medium_dash_dot',
            11 => 'dash_dot_dot',
            12 => 'medium_dash_dot_dot',
            13 => 'slant_dash_dot',
        );

        if (!$format->{IgnoreFont}) {
            $format_data->{size} = $format->{Font}{Height};
            $format_data->{color} = $format->{Font}{Color}
                unless lc($format->{Font}{Color}) eq '#ffffff'; # XXX
        }
        if (!$format->{IgnoreFill}) {
            $format_data->{bg_color} = $format->{Fill}[1]
                unless $format->{Fill}[1] eq '#000000'; # XXX
        }
        if (!$format->{IgnoreBorder}) {
            $format_data->{border_color} = $format->{BdrColor};
            if (any { $_ != 0 } @{ $format->{BdrStyle} }) { # XXX
                $format_data->{border} = [
                    map { $border{$_} } @{ $format->{BdrStyle} }
                ];
            }
        }
        if (!$format->{IgnoreAlignment}) {
            $format_data->{align} = $halign{$format->{AlignH}}
                unless $format->{AlignH} == 0;
            $format_data->{valign} = $valign{$format->{AlignV}}
                unless $format->{AlignV} == 2;
            $format_data->{text_wrap} = JSON::true
                if $format->{Wrap};
        }
        if (!$format->{IgnoreNumberFormat}) {
            my $wb = $self->excel;
            $format_data->{num_format} = $wb->{FormatStr}{$format->{FmtIdx}}
                unless $wb->{FormatStr}{$format->{FmtIdx}} eq 'GENERAL';
        }
    }

    my $data = {
        contents => $contents,
        type     => $type,
        ($formula ? (formula => $formula) : ()),
        (keys %$format_data ? (format => $format_data) : ()),
    };

    return $data;
}

no Moose::Role;

1;
