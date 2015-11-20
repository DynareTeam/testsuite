import glob
import pandas as pd

from bokeh.io import vplot
from bokeh.plotting import figure, output_file, show, save
from bokeh.models import ColumnDataSource, LinearAxis, Range1d, HoverTool, OpenURL, TapTool

# Set vars
octavecolor="#CC6633"
matlabcolor="#3366CC"
output_file("index.html")
line_width=2
circle_size=10
opacity=0.7


plots = {}
files = glob.glob('./*.m.csv')
files = [f.replace('.m.csv', '') for f in files]
for csvfile in files:
    # Read in data
    mdata = pd.read_csv(csvfile + '.m.csv', parse_dates=['Date'])
    odata = pd.read_csv(csvfile + '.o.csv', parse_dates=['Date'])

    mdata['ShortSHA'] = mdata['SHA'].str[:7]
    odata['ShortSHA'] = odata['SHA'].str[:7]

    # Set up mouse over
    hover = HoverTool(
        tooltips="""
        <div>
            <div>
                <span style="font-size: 10px;">SHA</span>
                <span style="font-size: 12px; color: #696;">@shortSHA</span>
            </div>
        </div>
        """
    )

    # Setup figure
    plots[csvfile] = figure(title=mdata.columns.values[1],
                            y_axis_label="Matlab CPU time",
                            x_axis_type="datetime",
                            width=800, height=250,
                            logo=None,
                            toolbar_location=None,
                            tools=["tap",hover])
    plots[csvfile].yaxis.axis_label_text_color=matlabcolor

    # Set up on click
    url = "https://github.com/DynareTeam/dynare/commit/@longSHA"
    taptool = plots[csvfile].select(type=TapTool)
    taptool.callback = OpenURL(url=url)

    # Matlab line on default y-axis
    msource = ColumnDataSource(
        data=dict(
            x=mdata['Date'],
            y=mdata[mdata.columns.values[1]],
            shortSHA=mdata['ShortSHA'],
            longSHA=mdata['SHA']
        )
    )

    # Octave line on right y-axis
    osource = ColumnDataSource(
        data=dict(
            x=odata['Date'],
            y=odata[mdata.columns.values[1]],
            shortSHA=mdata['ShortSHA'],
            longSHA=mdata['SHA']
        )
    )

    # Prepare Right (Octave) Axis
    octmin = min(odata[odata.columns.values[1]]) - 1
    octmax = max(odata[odata.columns.values[1]]) + 1
    plots[csvfile].extra_y_ranges = {"octave": Range1d(start=octmin, end=octmax)}
    plots[csvfile].add_layout(LinearAxis(y_range_name="octave", axis_label="Octave CPU time", axis_label_text_color=octavecolor), 'right')

    # Plot Matlab Line
    plots[csvfile].line('x', 'y', color=matlabcolor, line_width=line_width, line_alpha=opacity, source=msource)
    plots[csvfile].circle('x', 'y', color=matlabcolor, size=circle_size, source=msource, alpha=0)

    # Plot Octave line
    plots[csvfile].line('x', 'y', color=octavecolor, line_width=line_width, line_alpha=opacity, source=osource)
    plots[csvfile].circle('x', 'y', color=octavecolor, size=circle_size, source=osource, alpha=0)

p = vplot(*plots.values())
save(p)
