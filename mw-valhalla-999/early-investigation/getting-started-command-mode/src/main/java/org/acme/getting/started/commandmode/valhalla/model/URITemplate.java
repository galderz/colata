package org.acme.getting.started.commandmode.valhalla.model;

/**
 * Simplified stand-in for org.jboss.resteasy.reactive.server.mapping.URITemplate.
 *
 * The real URITemplate contains a template string and an array of TemplateComponent
 * segments. For benchmark purposes we model it as a reference-type field in RequestMatch
 * to match the actual field type (URITemplate, not String) used in the Quarkus source.
 */
public final class URITemplate {
    public final String template;
    public final int segments;

    public URITemplate(String template) {
        this.template = template;
        this.segments = (int) template.chars().filter(c -> c == '/').count();
    }

    @Override
    public String toString() {
        return template;
    }
}
