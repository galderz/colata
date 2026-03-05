import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import org.w3c.dom.*;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

public class CLion {
    public static void main(String[] args) throws Exception
    {
        final Path jdkHome = Path.of(args[0]);
        final String confName = args[1];

        final Path confPath = jdkHome.resolve("build", confName);
        final Path workspaceXmlPath = confPath.resolve(".idea/workspace.xml");
        final Path customTargetsXmlPath = confPath.resolve(".idea/customTargets.xml");
        final Path externalToolsXmlPath = confPath.resolve(".idea/tools/External Tools.xml");
        final Path miscXmlPath = confPath.resolve(".idea/misc.xml");

        updateWorkspaceXml(confName, workspaceXmlPath);
        createCustomTargetsXml(customTargetsXmlPath);
        createExternalToolsXml(jdkHome, confName, externalToolsXmlPath);

        // Update misc.xml
        updateMiscXml(miscXmlPath);
    }

    private static void updateWorkspaceXml(String confName, Path workspaceXmlPath) throws Exception {
        Document doc = parseXmlFile(workspaceXmlPath);

        NodeList components = doc.getElementsByTagName("component");
        for (int i = 0; i < components.getLength(); i++)
        {
            Element component = (Element) components.item(i);
            if (component.getAttribute("name").equals("PropertiesComponent"))
            {
                String cdata = component.getTextContent();
                String updatedCdata = cdata.replaceFirst(
                    "}"
                    , ", \"Custom Build Application.--version.executor\": \"Run\"}"
                );
                component.setTextContent(updatedCdata);
            }
            if (component.getAttribute("name").equals("RunManager"))
            {
                component.appendChild(createConfigurationElement(confName, doc));
                component.appendChild(createListElement(doc));
            }
        }

        writeXmlFile(workspaceXmlPath, doc);
    }

    private static Element createConfigurationElement(String confName, Document doc) {
        Element configuration = doc.createElement("configuration");
        configuration.setAttribute("name", "--version");
        configuration.setAttribute("type", "CLionExternalRunConfiguration");
        configuration.setAttribute("factoryName", "Application");
        configuration.setAttribute("PROGRAM_PARAMS", "--version");
        configuration.setAttribute("REDIRECT_INPUT", "false");
        configuration.setAttribute("ELEVATE", "false");
        configuration.setAttribute("USE_EXTERNAL_CONSOLE", "false");
        configuration.setAttribute("EMULATE_TERMINAL", "false");
        configuration.setAttribute("PASS_PARENT_ENVS_2", "true");
        configuration.setAttribute("PROJECT_NAME", confName);
        configuration.setAttribute("TARGET_NAME", "Build JDK");
        configuration.setAttribute("CONFIG_NAME", "Build JDK");
        configuration.setAttribute("RUN_PATH", "$PROJECT_DIR$/jdk/bin/java");

        Element method = doc.createElement("method");
        method.setAttribute("v", "2");
        Element option = doc.createElement("option");
        option.setAttribute("name", "CLION.EXTERNAL.BUILD");
        option.setAttribute("enabled", "true");
        method.appendChild(option);
        configuration.appendChild(method);

        return configuration;
    }

    private static Element createListElement(Document doc) {
        Element list = doc.createElement("list");
        Element item = doc.createElement("item");
        item.setAttribute("itemvalue", "Custom Build Application.--version");
        list.appendChild(item);
        return list;
    }

    private static void createCustomTargetsXml(Path customTargetsXmlPath) throws Exception {
        String xmlContent = """
                <?xml version="1.0" encoding="UTF-8"?>
                <project version="4">
                  <component name="CLionExternalBuildManager">
                    <target id="26b8df82-dc03-436c-bb25-1abdec17a36e" name="Build JDK" defaultType="TOOL">
                      <configuration id="da2d65f3-3d09-428e-9944-89890af724cb" name="Build JDK">
                        <build type="TOOL">
                          <tool actionId="Tool_External Tools_make slow" />
                        </build>
                        <clean type="TOOL">
                          <tool actionId="Tool_External Tools_clean slow" />
                        </clean>
                      </configuration>
                    </target>
                  </component>
                </project>
                """;

        Files.createDirectories(customTargetsXmlPath.getParent());
        Files.writeString(customTargetsXmlPath, xmlContent);
    }

    private static void createExternalToolsXml(Path jdkHome, String confName, Path externalToolsXmlPath) throws IOException {
        String xmlContent = """
                <toolSet name="External Tools">
                  <tool name="make slow" showInMainMenu="false" showInEditor="false" showInProject="false" showInSearchPopup="false" disabled="false" useConsole="true" showConsoleOnStdOut="false" showConsoleOnStdErr="false" synchronizeAfterRun="true">
                    <exec>
                      <option name="COMMAND" value="make" />
                      <option name="PARAMETERS" value="CONF=%1$s" />
                      <option name="WORKING_DIRECTORY" value="%2$s" />
                    </exec>
                  </tool>
                  <tool name="clean slow" showInMainMenu="false" showInEditor="false" showInProject="false" showInSearchPopup="false" disabled="false" useConsole="true" showConsoleOnStdOut="false" showConsoleOnStdErr="false" synchronizeAfterRun="true">
                    <exec>
                      <option name="COMMAND" value="make" />
                      <option name="PARAMETERS" value="CONF=%1$s clean" />
                      <option name="WORKING_DIRECTORY" value="%2$s" />
                    </exec>
                  </tool>
                </toolSet>
                """
            .formatted(confName, jdkHome);

        Files.createDirectories(externalToolsXmlPath.getParent());
        Files.writeString(externalToolsXmlPath, xmlContent);
    }

    private static void updateMiscXml(Path miscXmlPath) throws Exception {
        Document doc = parseXmlFile(miscXmlPath);

        NodeList components = doc.getElementsByTagName("component");
        for (int i = 0; i < components.getLength(); i++)
        {
            Element component = (Element) components.item(i);
            if (component.getAttribute("name").equals("CompDBWorkspace"))
            {
                Element contentRoot = doc.createElement("contentRoot");
                contentRoot.setAttribute("DIR", "$PROJECT_DIR$/../..");
                component.appendChild(contentRoot);
            }
        }

        writeXmlFile(miscXmlPath, doc);
    }

    private static Document parseXmlFile(Path path) throws Exception {
        DocumentBuilderFactory dbFactory = DocumentBuilderFactory.newInstance();
        DocumentBuilder dBuilder = dbFactory.newDocumentBuilder();
        return dBuilder.parse(Files.newInputStream(path));
    }

    private static void writeXmlFile(Path path, Document doc) throws Exception {
        TransformerFactory transformerFactory = TransformerFactory.newInstance();
        Transformer transformer = transformerFactory.newTransformer();
        transformer.setOutputProperty(OutputKeys.INDENT, "yes");
        DOMSource source = new DOMSource(doc);
        StreamResult result = new StreamResult(Files.newOutputStream(path));
        transformer.transform(source, result);
    }
}
