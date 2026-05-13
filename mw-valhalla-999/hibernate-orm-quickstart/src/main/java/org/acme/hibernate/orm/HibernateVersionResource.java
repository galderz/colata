package org.acme.hibernate.orm;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/hibernate-version")
public class HibernateVersionResource {

    @GET
    @Produces(MediaType.TEXT_PLAIN)
    public String getVersion() {
        return "Hibernate ORM Version: " + org.hibernate.Version.getVersionString();
    }
}
