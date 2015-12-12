
from docutils.parsers.rst import directives
from docutils.parsers.rst import Directive
from docutils import nodes

class DemeterDocException(Exception): pass

class demeter(nodes.Element):
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

