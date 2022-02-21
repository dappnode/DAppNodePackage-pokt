import React from "react";
import { Container } from "react-bootstrap";
import "./Footer.scss";
import Media from "./Media";

export default function Footer() {
  return (
    <Container className="footer">
      <Media />
    </Container>
  );
}
