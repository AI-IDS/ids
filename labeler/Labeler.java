/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package labeler;

import java.util.*;
import java.io.*;
import java.text.SimpleDateFormat;

import javax.xml.parsers.*;
import org.joda.time.DateTime;
import org.xml.sax.*;
import org.xml.sax.helpers.*;

/**
 *
 * @author Host
 */
public class Labeler extends DefaultHandler
{

    /**
     * Constants used for JAXP 1.2
     */
    static final String JAXP_SCHEMA_LANGUAGE
            = "http://java.sun.com/xml/jaxp/properties/schemaLanguage";
    static final String W3C_XML_SCHEMA
            = "http://www.w3.org/2001/XMLSchema";
    static final String JAXP_SCHEMA_SOURCE
            = "http://java.sun.com/xml/jaxp/properties/schemaSource";

    /**
     * A Hashtable with tag names as keys and Integers as values
     */
    private HashMap<String, Map.Entry<String, Integer>> hashMap;
    private List<String> tags;
    private String currentElement;
    private StringBuilder currentHash;

    public Labeler(List<String> tags)
    {
        hashMap = new HashMap<>();
        currentHash = new StringBuilder();
        this.tags = tags;
    }

    // Parser calls this once at the beginning of a document
    public void startDocument() throws SAXException
    {

    }

    // Parser calls this for each element in a document
    public void startElement(String namespaceURI, String localName, String qName, Attributes atts) throws SAXException
    {
        currentElement = localName;
    }

    // process the content of an element
    public void characters(char[] ch, int start, int length)
    {
        if (currentElement == null)
        {
            return;
        }
        if (tags.contains(currentElement))
        {
            if (currentHash.length() > 0)
            {
                currentHash.append(",");
            }
            currentHash.append(ch, start, length);
        } else if (currentElement.equals("Tag"))
        {
            String key = currentHash.toString().replaceAll("\\s+", "");
            if (hashMap.containsKey(key))
            {
                //System.out.println("duplicate key:"+key);
            }
            hashMap.put(key, new AbstractMap.SimpleEntry<>(new String(ch, start, length), 0));
            currentHash.setLength(0);
        }
    }

    public void endElement(String namespaceURI, String localName, String qName) throws SAXException
    {
        currentElement = null;
    }

    // Parser calls this once after parsing a document
    public void endDocument() throws SAXException
    {
//        for (Map.Entry<String, String> entry : hashMap.entrySet())
//        {
//            System.out.println(entry.getKey() + "," + entry.getValue());
//        }
    }

    public String toString()
    {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, Map.Entry<String, Integer>> entry : hashMap.entrySet())
        {
            sb.append(entry.getKey() + "," + entry.getValue().getKey() + "," + entry.getValue().getValue() + "\n");
        }
        return sb.toString();
    }

    /**
     * Convert from a filename to a file URL.
     */
    private static String convertToFileURL(String filename)
    {
        // On JDK 1.2 and later, simplify this to:
        // "path = file.toURL().toString()".
        String path = new File(filename).getAbsolutePath();
        if (File.separatorChar != '/')
        {
            path = path.replace(File.separatorChar, '/');
        }
        if (!path.startsWith("/"))
        {
            path = "/" + path;
        }
        return "file:" + path;
    }

    static public void main(String[] args) throws Exception
    {
        // parsing arguments

        List<String> xmls = new ArrayList<>();
        int i = 0;
    
        int offset =0; // Offset for date and time

//        if (args.length!=1 && args.length!=3)
//        {
//            System.err.println("Only 1 or 3 argumets");
//            return;
//        }
        if (args[0].equals("-t"))
        {
            offset = Integer.parseInt(args[1]);
            i = 2;
        } else
        {
            i = 0;
        }

        while (i < args.length - 2)
        {
            xmls.add(args[i++]);
        }

        // Set the date time format
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss");

        // Create a JAXP SAXParserFactory and configure it
        SAXParserFactory spf = SAXParserFactory.newInstance();

        // Set namespaceAware to true to get a parser that corresponds to
        // the default SAX2 namespace feature setting.  This is necessary
        // because the default value from JAXP 1.0 was defined to be false.
        spf.setNamespaceAware(true);

        // Validation part 1: set whether validation is on
        spf.setValidating(false);

        // Create a JAXP SAXParser
        SAXParser saxParser = spf.newSAXParser();

        // Get the encapsulated SAX XMLReader
        XMLReader xmlReader = saxParser.getXMLReader();

        // Set the ContentHandler of the XMLReader
        Labeler labeler = new Labeler(Arrays.asList("source", "protocolName", "sourcePort", "destination", "destinationPort", "stopDateTime"));
        //Labeler labeler = new Labeler(Arrays.asList("source", "protocolName", "sourcePort", "destination", "destinationPort"));

        xmlReader.setContentHandler(labeler);

        // Set an ErrorHandler before parsing
        xmlReader.setErrorHandler(new MyErrorHandler(System.err));

        //Tell the XMLReader to parse the XML document
        for (String xml : xmls)
        {
            xmlReader.parse(convertToFileURL(xml));
        }

        BufferedWriter writer = null;
        BufferedReader reader = null;

        try
        {
            int max = 10;
            HashMap<Integer, Integer> offsets = new HashMap<>();
            offsets.put(0, 0);

            for (int j = 1; j <= max; j++)
            {
                offsets.put(j, 0);
                offsets.put(-j, 0);
            }

            while (true)
            {
                reader = new BufferedReader(new FileReader(args[args.length - 2]));
                String line = "";
                int count = 0;
                int missed = 0;

                while ((line = reader.readLine()) != null)
                {
                    count++;
                    String[] values = line.split(",");
                    Date date = new Date(dateFormat.parse(values[32]).getTime() + offset * 1000); // shift by offset
                    String keyBase = values[28] + "," + values[1] + "_ip" + "," + values[29] + "," + values[30] + "," + values[31] + ",";
                    Calendar gc = new GregorianCalendar();
                    Date tmp_date;

                    Map.Entry<String, Integer> value = null;

                    for (Map.Entry<Integer, Integer> off : offsets.entrySet())
                    {
                        gc.setTime(date);
                        gc.add(Calendar.SECOND, off.getKey());
                        tmp_date = gc.getTime();
                        String key = keyBase + dateFormat.format(tmp_date);
                        value = labeler.hashMap.get(key);
                        if (value != null)
                        {
                            offsets.put(off.getKey(), off.getValue() + 1);
                            break;
                        }
                    }
                    if (value == null)
                    {
                        missed++;
                    }
                }
                reader.close();
                System.out.println(offset + "," + ((1 - (double) missed / count) * 100) + "%");

                int offset_new = offset + offsets.entrySet().stream().max((entry1, entry2) -> entry1.getValue() > entry2.getValue() ? 1 : -1).get().getKey();

                if (offset == offset_new)
                {
                    break;
                } else
                {
                    offset = offset_new;
                    offsets.entrySet().forEach(entry->entry.setValue(0));
                }
            }

            String line = "";
            int count = 0;
            int missed = 0;

            reader = new BufferedReader(new FileReader(args[args.length - 2]));
            writer = new BufferedWriter(new FileWriter(args[args.length - 1]));

            while ((line = reader.readLine()) != null)
            {
                count++;
                String[] values = line.split(",");
                Date date = new Date(dateFormat.parse(values[32]).getTime() + offset * 1000); // shift by offset
                String keyBase = values[28] + "," + values[1] + "_ip" + "," + values[29] + "," + values[30] + "," + values[31] + ",";
                Calendar gc = new GregorianCalendar();
                Date tmp_date;

                Integer cor_off = null;
                Map.Entry<String, Integer> value = null;

                for (Map.Entry<Integer, Integer> off : offsets.entrySet())
                {
                    gc.setTime(date);
                    gc.add(Calendar.SECOND, off.getKey());
                    tmp_date = gc.getTime();
                    String key1 = keyBase + dateFormat.format(tmp_date);
                    value = labeler.hashMap.get(key1);
                    if (value != null)
                    {
                        labeler.hashMap.put(key1, new AbstractMap.SimpleEntry<>(value.getKey(), value.getValue() + 1));
                        cor_off = off.getKey();
                        offsets.put(off.getKey(), off.getValue() + 1);
                        break;
                    }
                }

                if (value == null)
                {
                    missed++;
                }

                writer.write(line + "," + ((value == null) ? "miss" : value.getKey()) + "," + cor_off + "\n");
            }

            //writer.write(labeler.toString());
            System.out.println(offset + "," + ((1 - (double) missed / count) * 100) + "%");

        } finally
        {
            if (writer != null)
            {
                writer.close();
            }
            if (reader != null)
            {
                reader.close();
            }
        }
    }

    // Error handler to report errors and warnings
    private static class MyErrorHandler implements ErrorHandler
    {

        /**
         * Error handler output goes here
         */
        private PrintStream out;

        MyErrorHandler(PrintStream out)
        {
            this.out = out;
        }

        /**
         * Returns a string describing parse exception details
         */
        private String getParseExceptionInfo(SAXParseException spe)
        {
            String systemId = spe.getSystemId();
            if (systemId == null)
            {
                systemId = "null";
            }
            String info = "URI=" + systemId
                    + " Line=" + spe.getLineNumber()
                    + ": " + spe.getMessage();
            return info;
        }

        // The following methods are standard SAX ErrorHandler methods.
        // See SAX documentation for more info.
        public void warning(SAXParseException spe) throws SAXException
        {
            out.println("Warning: " + getParseExceptionInfo(spe));
        }

        public void error(SAXParseException spe) throws SAXException
        {
            String message = "Error: " + getParseExceptionInfo(spe);
            throw new SAXException(message);
        }

        public void fatalError(SAXParseException spe) throws SAXException
        {
            String message = "Fatal Error: " + getParseExceptionInfo(spe);
            throw new SAXException(message);
        }
    }
}
