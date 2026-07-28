from pathlib import Path

ARB = Path(__file__).resolve().parents[1] / "lib" / "l10n" / "arb"

FR = """
  "parentInsights": "Apercus",
  "parentInsightsEmpty": "Ajoutez un profil enfant pour voir les apercus.",
  "certificateTitle": "Certificat",
  "certificateSubtitle": "Celebrez les progres avec un certificat",
  "certificateHeading": "CERTIFICAT D APPRENTISSAGE",
  "certificateNeedChild": "Choisissez d abord un profil enfant.",
  "certificateBody": "Niveau {level} - {lessons} lecons - {stars} etoiles",
  "readingEase": "Lecture facilitee",
  "readingEaseBody": "Espacement plus large pour une lecture plus aisee",
  "highContrast": "Contraste eleve",
  "highContrastBody": "Couleurs et bordures plus fortes",
  "reducedMotion": "Moins de mouvement",
  "reducedMotionBody": "Animations plus calmes",
  "analyticsOptIn": "Ameliorer Watoto",
  "analyticsOptInBody": "Statistiques produit optionnelles et respectueuses de la vie privee",
  "exportData": "Exporter les donnees",
  "exportDataBody": "Copier un resume JSON des progres locaux",
  "exportDataCopied": "Donnees copiees",
  "deleteChild": "Supprimer {name}",
  "deleteChildBody": "Supprime ce profil et ses progres sur cet appareil",
  "deleteChildConfirm": "Action irreversible sur cet appareil. Continuer?",
  "delete": "Supprimer",
  "cancel": "Annuler",
  "syncPending": "{count} elements en attente de sync",
  "premiumMapFree": "Gratuit: etapes 1-5. Premium: etapes 6-10."
}
"""

SW = """
  "parentInsights": "Maarifa",
  "parentInsightsEmpty": "Ongeza wasifu wa mtoto ili uone maarifa.",
  "certificateTitle": "Cheti",
  "certificateSubtitle": "Sherehekea maendeleo kwa cheti",
  "certificateHeading": "CHETI CHA KUJIFUNZA",
  "certificateNeedChild": "Chagua wasifu wa mtoto kwanza.",
  "certificateBody": "Kiwango {level} - Masomo {lessons} - Nyota {stars}",
  "readingEase": "Urahisi wa kusoma",
  "readingEaseBody": "Nafasi pana za herufi na mistari",
  "highContrast": "Tofauti kubwa ya rangi",
  "highContrastBody": "Rangi na mipaka thabiti zaidi",
  "reducedMotion": "Punguza mwendo",
  "reducedMotionBody": "Uhuishaji tulivu",
  "analyticsOptIn": "Saidia kuboresha Watoto",
  "analyticsOptInBody": "Takwimu za hiari, zinazolinda faragha",
  "exportData": "Hamisha data",
  "exportDataBody": "Nakili muhtasari wa JSON wa maendeleo",
  "exportDataCopied": "Data imenakiliwa",
  "deleteChild": "Futa {name}",
  "deleteChildBody": "Inaondoa wasifu na maendeleo kwenye kifaa hiki",
  "deleteChildConfirm": "Haiwezi kurekebishwa kwenye kifaa hiki. Endelea?",
  "delete": "Futa",
  "cancel": "Ghairi",
  "syncPending": "Vipengee {count} vinasubiri kusawazishwa",
  "premiumMapFree": "Bure: hatua 1-5. Premium: hatua 6-10."
}
"""


def append(name: str, extra: str) -> None:
    p = ARB / name
    text = p.read_text(encoding="utf-8")
    if "parentInsights" in text:
        print(name, "already has keys")
        return
    text = text.rstrip()
    assert text.endswith("}")
    body = text[:-1].rstrip()
    lines = body.splitlines()
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip():
            if not lines[i].rstrip().endswith(","):
                lines[i] = lines[i].rstrip() + ","
            break
    body = "\n".join(lines)
    p.write_text(body + "\n" + extra.lstrip(), encoding="utf-8")
    print("updated", name)


if __name__ == "__main__":
    append("app_fr.arb", FR)
    append("app_sw.arb", SW)
