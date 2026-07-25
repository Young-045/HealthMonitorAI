using System.ComponentModel.DataAnnotations;

namespace HealthMonitorAI.Api.Contracts;

/// <summary>Identifies a meal analysis task submitted by the Apple client.</summary>
public sealed record AnalyzeMealRequest
{
    /// <summary>Stable client-generated identifier used for retries and diagnostics.</summary>
    [Required, MaxLength(100)]
    public required string RequestId { get; init; }

    /// <summary>IETF language tag used for food names and model output.</summary>
    [Required, MaxLength(20)]
    public required string Locale { get; init; }

    /// <summary>Optional user description containing portions or cooking details.</summary>
    [MaxLength(2_000)]
    public string? Description { get; init; }

    /// <summary>Optional compressed meal image.</summary>
    public MealImageRequest? Image { get; init; }
}

/// <summary>Contains an image encoded for the first API contract version.</summary>
public sealed record MealImageRequest
{
    /// <summary>Supported image MIME type.</summary>
    [Required, MaxLength(50)]
    public required string ContentType { get; init; }

    /// <summary>Base64-encoded image bytes without a data URL prefix.</summary>
    [Required]
    public required string Base64 { get; init; }
}

/// <summary>Represents a structured meal analysis returned by an AI provider.</summary>
public sealed record MealAnalysisResponse(
    string SchemaVersion,
    string RequestId,
    string ImageType,
    RecognizedProductResponse? Product,
    MealPackageInformationResponse? Package,
    RecognizedNutritionLabelResponse? NutritionLabel,
    IReadOnlyList<RecognizedFoodResponse> Foods,
    IReadOnlyList<string> Warnings,
    string Model,
    long ProcessingTimeMilliseconds);

public sealed record RecognizedProductResponse(
    string? Name,
    string? Brand,
    string? Barcode,
    decimal Confidence);

public sealed record MealPackageInformationResponse(
    decimal? NetWeightGrams,
    decimal? DrainedWeightGrams,
    decimal? ServingSizeGrams,
    decimal? ServingsPerPackage,
    decimal Confidence);

public sealed record RecognizedNutritionLabelResponse(
    bool Present,
    string Basis,
    string? BasisDescription,
    decimal? BasisQuantity,
    string? BasisUnit,
    decimal? EnergyKilocalories,
    decimal? EnergyKilojoules,
    decimal? ProteinGrams,
    decimal? CarbohydrateGrams,
    decimal? FatGrams,
    decimal? FiberGrams,
    decimal? SugarGrams,
    decimal? SodiumMilligrams,
    decimal? SaltEquivalentGrams,
    string? RawText,
    IReadOnlyList<string> UnreadableFields,
    decimal Confidence);

/// <summary>Represents one recognized food with an explicit confidence and uncertainty range.</summary>
public sealed record RecognizedFoodResponse(
    string Name,
    decimal EstimatedWeightGrams,
    WeightRangeResponse WeightRange,
    string? CookingMethod,
    decimal Confidence,
    IReadOnlyList<string> Uncertainties);

/// <summary>Represents the plausible lower and upper bounds for a food weight.</summary>
public sealed record WeightRangeResponse(decimal MinimumGrams, decimal MaximumGrams);

/// <summary>Represents the official AI allowance for the current account and period.</summary>
public sealed record AiUsageResponse(
    int MealAnalysesUsed,
    int MealAnalysesLimit,
    DateTimeOffset PeriodEndsAt);
