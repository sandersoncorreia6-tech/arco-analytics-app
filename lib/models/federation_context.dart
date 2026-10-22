enum FederativeLevel { confederation, stateFederation, league }

class GoverningBody {
  final String id;
  final String acronym;
  final String name;
  final FederativeLevel level;
  final String? parentId;
  final String countryCode;
  final String stateCode;

  const GoverningBody({
    required this.id,
    required this.acronym,
    required this.name,
    required this.level,
    this.parentId,
    this.countryCode = 'BR',
    this.stateCode = '',
  });

  static const cbb = GoverningBody(
    id: 'cbb',
    acronym: 'CBB',
    name: 'Confederação Brasileira de Basketball',
    level: FederativeLevel.confederation,
  );

  static const fpb = GoverningBody(
    id: 'fpb_sp',
    acronym: 'FPB',
    name: 'Federação Paulista de Basketball',
    level: FederativeLevel.stateFederation,
    parentId: 'cbb',
    stateCode: 'SP',
  );
}

class ExternalTeamIdentity {
  final String source;
  final String officialName;
  final String governingBodyId;
  final String? externalId;
  final bool verifiedFromPublicSource;

  const ExternalTeamIdentity({
    required this.source,
    required this.officialName,
    required this.governingBodyId,
    this.externalId,
    this.verifiedFromPublicSource = false,
  });
}

class FederativeLink {
  final String confederationId;
  final String stateFederationId;
  final String? clubRegistrationId;
  final bool officialRegistrationIdVerified;
  final List<ExternalTeamIdentity> externalIdentities;

  const FederativeLink({
    required this.confederationId,
    required this.stateFederationId,
    this.clubRegistrationId,
    this.officialRegistrationIdVerified = false,
    this.externalIdentities = const [],
  });

  static const tupaFpb = FederativeLink(
    confederationId: 'cbb',
    stateFederationId: 'fpb_sp',
    officialRegistrationIdVerified: false,
    externalIdentities: [
      ExternalTeamIdentity(
        source: 'FPB',
        officialName: 'ATB - ASSOCIAÇÃO TUPÃ BASQUETE',
        governingBodyId: 'fpb_sp',
        verifiedFromPublicSource: true,
      ),
      ExternalTeamIdentity(
        source: 'FPB',
        officialName: 'F.R. TUPÃ',
        governingBodyId: 'fpb_sp',
        verifiedFromPublicSource: true,
      ),
      ExternalTeamIdentity(
        source: 'FPB',
        officialName: 'TUPÃ BASQUETE',
        governingBodyId: 'fpb_sp',
        verifiedFromPublicSource: true,
      ),
    ],
  );
}
