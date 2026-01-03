/**
 * Configuration parsers for different file formats.
 *
 * <p>This package provides parsers for:</p>
 * <ul>
 *   <li>{@link com.natsu.jefag.common.config.parser.YamlConfigParser} - YAML format using SnakeYAML</li>
 *   <li>{@link com.natsu.jefag.common.config.parser.JsonConfigParser} - JSON format using Jackson</li>
 *   <li>{@link com.natsu.jefag.common.config.parser.TomlConfigParser} - TOML format using toml4j</li>
 * </ul>
 *
 * <p>Use {@link com.natsu.jefag.common.config.parser.ConfigParserFactory} to get parser instances:</p>
 * <pre>{@code
 * ConfigParser yamlParser = ConfigParserFactory.yaml();
 * ConfigParser jsonParser = ConfigParserFactory.json();
 * ConfigParser tomlParser = ConfigParserFactory.toml();
 *
 * // Auto-detect from file extension
 * ConfigParser parser = ConfigParserFactory.getParserForFile("config.yml");
 * }</pre>
 *
 * @see com.natsu.jefag.common.config.parser.ConfigParser
 * @see com.natsu.jefag.common.config.parser.ConfigParserFactory
 */
package com.natsu.jefag.common.config.parser;
