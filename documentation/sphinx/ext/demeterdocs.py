'''Sphinx roles for use with Demeter's documentation

- decoration of names of programs in Demeter, as well as Feff,
  Ifeffit, and Larch (colored and smallcaps)

     :demeter:`athena`

- decoration of configuration parameters (colored, preceded by a
  colored diamond, right arrow between group and parameter names)

     :configparam:`athena,autosave_frequency`

- decoration of data processing parameters (colored and surrounded by
  guillemots)

     :procparam:`e0`

- quoted text (default text, surrounded by proper opening and closing
  double quotation marks)

     :quoted:`this`

- mark -- insert a static image as a wrapped image, second argument
  refers to depth of page in source tree

     :mark:`bend,..`

- button -- write the text to look like a button, first argument is the
  text, second is the button style.  choices are light (Athena
  button), dark (keyboard key, default), orange (single group plot
  button), and purple (multiple group plot button)

     :button:`E,purple`

Sphinx directive

- linebreak, like sphinxtr's endpar, but intended for breaking wrapped
  figures.  in html, it inserts <br clear="all">

     .. linebreak::

Bruce Ravel (https://github.com/bruceravel/demeter)

'''

from docutils.parsers.rst import directives
from docutils.parsers.rst import Directive
from docutils import nodes

class DemeterDocException(Exception): pass




class demeter(nodes.Element):
    ''' decoration of names of programs in Demeter, as well as Feff,
        Ifeffit, and Larch (colored and smallcaps)
    '''
    pass
    
def demeter_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    color_spec = '#8C4112'
    text = text.strip().upper()
    demeter_node = demeter()
    #color_spec = //something//.builder.app.config.demeter_color
    demeter_node.children.append(nodes.Text(text))
    demeter_node['color_spec'] = color_spec
    return [demeter_node], []

def visit_demeter_html(self, node):
    self.body.append('<font size=-1 color="%s">' % node['color_spec'])

def depart_demeter_html(self, node):
    self.body.append('</font>')

def visit_demeter_latex(self, node):
    color_spec = node['color_spec'][1:]
    self.body.append('\n\\textsc{\\textcolor[HTML]{%s}{' % color_spec)

def depart_demeter_latex(self, node):
    self.body.append('}}')



    
class configparam(nodes.Element):
    ''' decoration of configuration parameters (colored, preceded by a
        colored diamond, right arrow between group and parameter names)
    '''
    pass

def configparam_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    color_spec = '#636A24'
    words =text.strip().split(',')
    configparam_node = configparam()
    #color_spec = //something//.builder.app.config.demeter_color
    string = u'\u2666' + words[0] + u'\u2192' + words[1]
    configparam_node.children.append(nodes.Text(string))
    configparam_node['color_spec'] = color_spec
    return [configparam_node], []

def visit_configparam_html(self, node):
    self.body.append('<font color="%s">' % node['color_spec'])

def depart_configparam_html(self, node):
    self.body.append('</font>')

def visit_configparam_latex(self, node):
    color_spec = node['color_spec'][1:]
    self.body.append('\n\\textcolor[HTML]{%s}{' % color_spec)

def depart_configparam_latex(self, node):
    self.body.append('}}')



class procparam(nodes.Element):
    ''' decoration of data processing parameters (colored and surrounded by
        guillemots)
    '''
    pass

def procparam_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    color_spec = '#387A38'
    text = text.strip()
    procparam_node = procparam()
    #color_spec = //something//.builder.app.proc.demeter_color
    text = u'\u00AB' + text + u'\u00BB'
    procparam_node.children.append(nodes.Text(text))
    procparam_node['color_spec'] = color_spec
    return [procparam_node], []

def visit_procparam_html(self, node):
    self.body.append('<tt><font color="%s">' % node['color_spec'])

def depart_procparam_html(self, node):
    self.body.append('</font></tt>')

def visit_procparam_latex(self, node):
    color_spec = node['color_spec'][1:]
    self.body.append('\n\texttt{\\textcolor[HTML]{%s}{' % color_spec)

def depart_procparam_latex(self, node):
    self.body.append('}}')


class quoted(nodes.Element):
    '''quoted text (default text, surrounded by proper opening and closing
       double quotation marks)
    '''
    pass

def quoted_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    text = text.strip()
    quoted_node = quoted()
    quoted_node.children.append(nodes.Text(text))
    return [quoted_node], []

def visit_quoted_html(self, node):
    self.body.append(u'\u201C')

def depart_quoted_html(self, node):
    self.body.append(u'\u201D')

def visit_quoted_latex(self, node):
    self.body.append("``")

def depart_quoted_latex(self, node):
    self.body.append("''")

class mark(nodes.Element):
    '''mark a section by inserting a static image

    This is used for the lightning bolt (essential material for
    mastery of the program) and the bend sign (difficult material to
    master)
    '''
    pass

def mark_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    words =text.strip().split(',')
    image = words[0]
    path = words[1]
    mark_node = mark()
    mark_node['image'] = image
    mark_node['path'] = path
    return [mark_node], []

def visit_mark_html(self, node):
    titles = {'somerights' : 'This is a Creative Commons Attribution-ShareAlike document',
              'rightclick' : 'Right mouse button',
              'leftclick'  : 'Left mouse button',
              'soon'       : 'Coming soon!',
              'bend'       : 'This is difficult material',
              'lightning'  : 'This is material a skilled user should know',
              'plot-icon'  : 'Transfer to the Plot list',
              }
    thistitle = titles[node['image']]
    self.body.append('<img alt="%s" title="%s" src="%s/_static/%s.png" hspace="3">' % (node['image'], thistitle, node['path'], node['image']))

def depart_mark_html(self, node):
    self.body.append('</a>')

def visit_mark_latex(self, node):
    self.body.append('%s!' % node['image'])

def depart_mark_latex(self, node):
    self.body.append(" ")



class linebreak(nodes.Element):
    pass

class LineBreakDirective(Directive):

    required_arguments = 0
    optional_arguments = 0

    has_content = False

    def run(self):
        return [linebreak()]

def visit_linebreak_latex(self, node):
    self.body.append('\n\n')

def depart_linebreak_latex(self, node):
    pass

def visit_linebreak_html(self, node):
    self.body.append('\n<br clear="all">\n')

def depart_linebreak_html(self, node):
    pass


class plotwindow(nodes.Element):
    pass

class PlotWindowDirective(Directive):

    required_arguments = 0
    optional_arguments = 0

    has_content = False

    def run(self):
        return [plotwindow()]

def visit_plotwindow_latex(self, node):
    self.body.append('\n\n')

def depart_plotwindow_latex(self, node):
    pass

def visit_plotwindow_html(self, node):
    self.body.append('<img alt="Plot window" src="../_static/plot.png" align="right" hspace="25">')

def depart_plotwindow_html(self, node):
    pass


class plotlist(nodes.Element):
    pass

class PlotListDirective(Directive):

    required_arguments = 0
    optional_arguments = 0

    has_content = False

    def run(self):
        return [plotlist()]

def visit_plotlist_latex(self, node):
    self.body.append('\n\n')

def depart_plotlist_latex(self, node):
    pass

def visit_plotlist_html(self, node):
    self.body.append('<img alt="Plot window" src="../_static/plotlist.png" align="right" hspace="25">')

def depart_plotlist_html(self, node):
    pass




class button(nodes.Element):
    '''button letters using keys.css
    '''
    pass

def button_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    words =text.strip().split(',')
    key = words[0]
    color = 'dark'
    if len(words) > 1: color = words[1]
    button_node = button()
    button_node['color'] = color
    button_node.children.append(nodes.Text(key))
    return [button_node], []

def visit_button_html(self, node):
    self.body.append('<kbd class="%s">' % node['color'])

def depart_button_html(self, node):
    self.body.append('</kbd>')

def visit_button_latex(self, node):
    self.body.append("\\texttt{")

def depart_button_latex(self, node):
    self.body.append("}")



def setup(app):
    app.add_role('demeter', demeter_role)
    app.add_node(demeter,
            html = (visit_demeter_html, depart_demeter_html),
            latex = (visit_demeter_latex, depart_demeter_latex)
            )
    app.add_role('configparam', configparam_role)
    app.add_node(configparam,
            html = (visit_configparam_html, depart_configparam_html),
            latex = (visit_configparam_latex, depart_configparam_latex)
            )
    app.add_role('procparam', procparam_role)
    app.add_node(procparam,
            html = (visit_procparam_html, depart_procparam_html),
            latex = (visit_procparam_latex, depart_procparam_latex)
            )
    app.add_role('quoted', quoted_role)
    app.add_node(quoted,
            html = (visit_quoted_html, depart_quoted_html),
            latex = (visit_quoted_latex, depart_quoted_latex)
            )
    app.add_role('mark', mark_role)
    app.add_node(mark,
            html = (visit_mark_html, depart_mark_html),
            latex = (visit_mark_latex, depart_mark_latex)
            )
    app.add_directive('linebreak', LineBreakDirective)
    app.add_node(linebreak,
            html = (visit_linebreak_html, depart_linebreak_html),
            latex = (visit_linebreak_latex, depart_linebreak_latex)
            )
    app.add_directive('plotwindow', PlotWindowDirective)
    app.add_node(plotwindow,
            html = (visit_plotwindow_html, depart_plotwindow_html),
            latex = (visit_plotwindow_latex, depart_plotwindow_latex)
            )
    app.add_directive('plotlist', PlotListDirective)
    app.add_node(plotlist,
            html = (visit_plotlist_html, depart_plotlist_html),
            latex = (visit_plotlist_latex, depart_plotlist_latex)
            )
    app.add_role('button', button_role)
    app.add_node(button,
            html = (visit_button_html, depart_button_html),
            latex = (visit_button_latex, depart_button_latex)
            )

