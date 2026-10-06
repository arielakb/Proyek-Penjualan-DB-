from django import template

register = template.Library()


@register.filter
def rupiah(v):
    return "Rp {:,.0f}".format(v).replace(",", ".")
