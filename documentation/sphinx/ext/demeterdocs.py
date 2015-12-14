'''
Sphinx roles for use with Demeter's documentation

- decoration of names of programs in Demeter, as well as Feff,
  Ifeffit, and Larch (colored and smallcaps)

- decoration of configuration parameters (colored, preceded by a
  colored diamond, right arrow between group and parameter names)

- decoration of data processing parameters (colored and surrounded by
  guillemots)

- quoted text (default text, surrounded by proper opening and closing
  double quotation marks)

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
    color_spec = '#033B0A'
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
    self.body.append('<kbd><font color="%s">' % node['color_spec'])

def depart_procparam_html(self, node):
    self.body.append('</font></kbd>')

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
    self.body.append('<img alt="%s!" src="%s/_static/%s.png" align="left" hspace="5">' % (node['image'], node['path'], node['image']))

def depart_mark_html(self, node):
    self.body.append('&nbsp;</a>')

def visit_mark_latex(self, node):
    self.body.append(" mark bolt!")

def depart_mark_latex(self, node):
    self.body.append(" ")



class linebreak(nodes.Element):
    '''linebreak text (default text, surrounded by proper opening and closing
       double quotation marks)
    '''
    pass

def linebreak_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    linebreak_node = linebreak()
    return [linebreak_node], []

def visit_linebreak_html(self, node):
    self.body.append('<br clear="all">')

def depart_linebreak_html(self, node):
    self.body.append('')

def visit_linebreak_latex(self, node):
    self.body.append("\\hfill\\break")

def depart_linebreak_latex(self, node):
    self.body.append("")





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
    app.add_role('linebreak', linebreak_role)
    app.add_node(linebreak,
            html = (visit_linebreak_html, depart_linebreak_html),
            latex = (visit_linebreak_latex, depart_linebreak_latex)
            )

